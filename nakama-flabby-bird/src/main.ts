/// <reference types="nakama-runtime" />

const MAX_VELOCITY = 800.0;
const MAX_POSITION_JUMP_PER_MS = 2.0;
const MIN_SCORE_INTERVAL_MS = 1500;
const POSITION_CORRECTION_INTERVAL_TICKS = 600;
const SYSTEM_USER_ID = "00000000-0000-0000-0000-000000000000";
const COUNTDOWN_TICK_RATE = 30;
const FINISH_DELAY_TICKS = 90;
const MIN_PLAYERS_TO_START = 2;
const INITIAL_COUNTDOWN = 3;
const GAME_START_GRACE_PERIOD_MS = 3000;

enum MatchPhase {
  WaitingForPlayers = "waiting",
  Countdown = "countdown",
  Playing = "playing",
  Finished = "finished",
}

interface PlayerState {
  presence: nkruntime.Presence;
  username: string;
  displayName?: string;
  birdY: number;
  velocity: number;
  isAlive: boolean;
  score: number;
  isInLobby: boolean;
  lastUpdateTime: number;
  lastScoreTime: number;
}

interface MatchState {
  players: Record<string, PlayerState>;
  presences: nkruntime.Presence[];
  currentPhase: MatchPhase;
  countdownValue: number;
  gameStartTime: number;
  winner: string | null;
  pipes: { id: number; x: number; gapY: number }[];
  nextPipeId: number;
  cleanedUp?: boolean;
  finishTickCounter?: number;
}

enum OpCode {
  LOBBY_UPDATE = 200,
  COUNTDOWN = 100,
  START_GAME = 101,
  GAME_FINISHED = 102,
  PLAYER_FLAP = 201,
  PLAYER_DIED = 202,
  PLAYER_SCORED = 203,
  PIPE_SPAWN = 204,
  POSITION_CORRECTION = 205,
  PLAYER_LEFT = 111,
}

const matchInit: nkruntime.MatchInitFunction = (ctx, logger, nk, params) => {
  const state: MatchState = {
    players: {},
    presences: [],
    currentPhase: MatchPhase.WaitingForPlayers,
    countdownValue: INITIAL_COUNTDOWN,
    gameStartTime: 0,
    winner: null,
    pipes: [],
    nextPipeId: 1,
    cleanedUp: false,
    finishTickCounter: 0,
  };

  return {
    state,
    tickRate: 60,
    label: "Multiplayer Flabby Bird",
  };
};

const matchJoinAttempt: nkruntime.MatchJoinAttemptFunction = (
  ctx, logger, nk, dispatcher, tick, state, presence, metadata
) => {
  if (state.currentPhase === MatchPhase.Finished) {
    return { state, accept: false, rejectMessage: "Match already finished." };
  }
  return { state, accept: true };
};



const matchJoin: nkruntime.MatchJoinFunction = (
  ctx, logger, nk, dispatcher, tick, state, presences
) => {
  for (const p of presences) {
    if (state.players[p.userId]) continue;

    let displayName = p.username;
    try {
      const account = nk.accountGetId(p.userId);
      if (account?.user) {
        displayName = account.user.displayName || account.user.username || p.username;
      }
    } catch (e) {
      // Fallback to username
    }

    state.players[p.userId] = {
      presence: p,
      username: p.username,
      displayName: displayName,
      birdY: 0.5,
      velocity: 0,
      isAlive: true,
      score: 0,
      isInLobby: false,
      lastUpdateTime: Date.now(),
      lastScoreTime: 0,
    };
    state.presences.push(p);

    broadcastLobbyUpdate(dispatcher, state);
  }

  return { state };
};

function broadcastLobbyUpdate(dispatcher: nkruntime.MatchDispatcher, state: nkruntime.MatchState) {
  const s = state as MatchState;
  const playersList: any[] = [];
  for (const id in s.players) {
    const pl = s.players[id];
    playersList.push({
      userId: id,
      username: pl.username,
      displayName: pl.displayName || pl.username,
      isInLobby: pl.isInLobby,
      isAlive: pl.isAlive,
      score: pl.score,
    });
  }

  dispatcher.broadcastMessage(
    OpCode.LOBBY_UPDATE,
    JSON.stringify({ event: "lobby_update", players: playersList }),
    s.presences
  );
}

function parseMessageData(nk: nkruntime.Nakama, data: ArrayBuffer): any {
  try {
    return JSON.parse(nk.binaryToString(data));
  } catch (e) {
    return {};
  }
}

const spawnPipe = (state: nkruntime.MatchState): { id: number; gapY: number } => {
  const s = state as MatchState;
  const id = s.nextPipeId++;
  const gapY = 0.33 + Math.random() * 0.5;
  return { id, gapY };
};


// MATCH LOOP
const matchLoop: nkruntime.MatchLoopFunction = (
  ctx, logger, nk, dispatcher, tick, state, messages
) => {
  switch (state.currentPhase) {
    // ===== WAITING =====
    case MatchPhase.WaitingForPlayers: {
      for (const msg of messages) {
        if (msg.opCode !== OpCode.LOBBY_UPDATE) continue;

        const player = state.players[msg.sender.userId];
        if (!player) continue;

        player.isInLobby = true;
        broadcastLobbyUpdate(dispatcher, state);
      }

      let readyCount = 0;
      for (const p of state.presences) {
        if (state.players[p.userId]?.isInLobby) readyCount++;
      }

      if (readyCount >= MIN_PLAYERS_TO_START) {
        state.currentPhase = MatchPhase.Countdown;
        state.countdownValue = INITIAL_COUNTDOWN;
      }
      break;
    }

    case MatchPhase.Countdown: {
      if (tick % COUNTDOWN_TICK_RATE === 0) {
        state.countdownValue -= 1;
        dispatcher.broadcastMessage(
          OpCode.COUNTDOWN,
          JSON.stringify({ event: "countdown", value: state.countdownValue }),
          state.presences
        );
      }

      if (state.countdownValue <= 0) {
        state.currentPhase = MatchPhase.Playing;
        state.gameStartTime = Date.now();
        dispatcher.broadcastMessage(
          OpCode.START_GAME,
          JSON.stringify({ event: "start_game" }),
          state.presences
        );
      }
      break;
    }

    case MatchPhase.Playing: {
      const tickDelta = 1 / 60;

      for (const msg of messages) {
        switch (msg.opCode) {
          
          case OpCode.PLAYER_FLAP: {
            const pl = state.players[msg.sender.userId];
            if (!pl || !pl.isAlive) break;

            const data = parseMessageData(nk, msg.data);
            if (!data) break;

            pl.birdY = data.yNormalized || pl.birdY;
            pl.velocity = data.velocity || 0;
            pl.lastUpdateTime = data.timestamp || Date.now();

            dispatcher.broadcastMessage(
              OpCode.PLAYER_FLAP,
              JSON.stringify({
                userId: msg.sender.userId,
                yNormalized: pl.birdY,
                velocity: pl.velocity,
                timestamp: Date.now()
              }),
              state.presences
            );
            break;
          }

          case OpCode.PLAYER_SCORED: {
            const pl = state.players[msg.sender.userId];
            if (!pl || !pl.isAlive) break;

            const data = parseMessageData(nk, msg.data);
            if (!data) break;

            pl.score = data.score || 0;
            pl.birdY = data.yNormalized || pl.birdY;
            pl.velocity = data.velocity || 0;
            pl.lastScoreTime = Date.now();
            pl.lastUpdateTime = data.timestamp || Date.now();

            dispatcher.broadcastMessage(
              OpCode.PLAYER_SCORED,
              JSON.stringify({
                userId: msg.sender.userId,
                score: pl.score,
                yNormalized: pl.birdY,
                velocity: pl.velocity
              }),
              state.presences
            );
            break;
          }

          case OpCode.PLAYER_DIED: {
            const pl = state.players[msg.sender.userId];
            if (!pl) break;

            const data = parseMessageData(nk, msg.data);
            if (!data) break;

            const wasAlive = pl.isAlive;
            pl.isAlive = false;
            pl.birdY = data.yNormalized || pl.birdY;
            pl.score = data.finalScore || pl.score;

            dispatcher.broadcastMessage(
              OpCode.PLAYER_DIED,
              JSON.stringify({
                userId: msg.sender.userId,
                yNormalized: pl.birdY,
                finalScore: pl.score
              }),
              state.presences
            );

            if (wasAlive) {
              let aliveCount = 0;
              for (const id in state.players) {
                if (state.players[id].isAlive) aliveCount++;
              }

              if (aliveCount > 0) break;

              let winnerId = "";
              let maxScore = -1;
              for (const id in state.players) {
                const p = state.players[id];
                if (p.score > maxScore) {
                  maxScore = p.score;
                  winnerId = id;
                }
              }

              const winnerName = state.players[winnerId]?.displayName || 
                                state.players[winnerId]?.username || 
                                "Unknown";
              state.currentPhase = MatchPhase.Finished;

              dispatcher.broadcastMessage(
                OpCode.GAME_FINISHED,
                JSON.stringify({
                  event: "game_finished",
                  winner: winnerName,
                  winnerId: winnerId,
                }),
                state.presences
              );
              
              return { state };
            }
            break;
          }
        }
      }

      if (tick % POSITION_CORRECTION_INTERVAL_TICKS === 0) {
        const corrections: any[] = [];
        for (const userId in state.players) {
          const pl = state.players[userId];
          corrections.push({
            userId: userId,
            yNormalized: pl.birdY,
            velocity: pl.velocity
          });
        }
        
        if (corrections.length > 0) {
          dispatcher.broadcastMessage(
            OpCode.POSITION_CORRECTION,
            JSON.stringify({ corrections: corrections }),
            state.presences
          );
        }
      }

      if (!state.nextPipeId) state.nextPipeId = 1;
      if (!state.pipes) state.pipes = [];

      const pipeSpeed = 150;
      const pipeInterval = 2;
      const canonicalWidth = 700;
      const pipeSpacing = pipeSpeed * pipeInterval;
      
      const startXNormalized = 1.0;
      const removeXNormalized = -0.15;

      for (const pipe of state.pipes) {
        const moveAmount = (pipeSpeed * tickDelta) / canonicalWidth;
        pipe.x -= moveAmount;
      }

      state.pipes = state.pipes.filter((p) => p.x > removeXNormalized);

      const lastPipe = state.pipes[state.pipes.length - 1];
      const spacingNormalized = pipeSpacing / canonicalWidth;
      const shouldSpawn = !lastPipe || lastPipe.x <= startXNormalized - spacingNormalized;

      if (shouldSpawn) {
        const { id, gapY } = spawnPipe(state);
        const xNormalized = startXNormalized;
        state.pipes.push({ id, x: xNormalized, gapY });

        dispatcher.broadcastMessage(
          OpCode.PIPE_SPAWN,
          JSON.stringify({
            id,
            xNormalized: xNormalized,
            gapYNormalized: gapY,
            serverTime: Date.now(),
          }),
          state.presences
        );
      }

      break;
    }

    case MatchPhase.Finished: {
      if (!state.cleanedUp) {
        removeWaitingMatch(nk, ctx.matchId);
        state.cleanedUp = true;
      }

      state.finishTickCounter = (state.finishTickCounter || 0) + 1;
      if (state.finishTickCounter >= 90) return null; 
      return { state };
    }
  }

  return { state };
};



// CLEANUP WAITING MATCHES
function removeWaitingMatch(nk: nkruntime.Nakama, matchId: string): void {
  const data = nk.storageRead([
    { collection: "matches", key: "waiting", userId: SYSTEM_USER_ID },
  ]);

  if (!data || data.length === 0) return;

  const current = data[0].value;
  if (!current || !current.ids || !Array.isArray(current.ids)) return;

  const updatedIds: string[] = [];
  for (const id of current.ids) {
    if (id !== matchId) updatedIds.push(id);
  }

  nk.storageWrite([
    {
      collection: "matches",
      key: "waiting",
      userId: SYSTEM_USER_ID,
      value: { ids: updatedIds },
    },
  ]);
}

// MATCH LEAVE
const matchLeave: nkruntime.MatchLeaveFunction = (
  ctx, logger, nk, dispatcher, tick, state, presences
) => {
  for (const p of presences) {
    // Xóa player khỏi danh sách
    delete state.players[p.userId];

    // Giữ lại những người vẫn còn online
    const newPresences: nkruntime.Presence[] = [];
    for (const pr of state.presences) {
      if (pr.userId !== p.userId) newPresences.push(pr);
    }
    state.presences = newPresences;

    // Gửi thông báo player rời lobby
    let totalPlayers = 0;
    for (const _ in state.players) totalPlayers++;

    dispatcher.broadcastMessage(
      111,
      JSON.stringify({
        event: "player_left",
        username: p.username,
        totalPlayers,
      }),
      state.presences
    );
  }

  // Nếu không còn ai → kết thúc trận
  let remaining = 0;
  for (const _ in state.players) remaining++;

  if (remaining === 0 && state.currentPhase !== MatchPhase.Finished) {
    state.currentPhase = MatchPhase.Finished;
  }

  return { state };
};



// MATCH SIGNAL
const matchSignal: nkruntime.MatchSignalFunction = (
  ctx, logger, nk, dispatcher, tick, state, data
) => {
  // Không sử dụng signal trong phiên bản này
  return { state };
};



// MATCH TERMINATE
const matchTerminate: nkruntime.MatchTerminateFunction = (
  ctx, logger, nk, dispatcher, tick, state, graceSeconds
) => {
  // Tự tạo trận mới sau khi trận cũ kết thúc
  if (ctx.matchId) {
    nk.matchCreate("flabby_bird_match");
  }

  return { state };
};

function addWaitingMatch(nk: nkruntime.Nakama, matchId: string): void {
  const res = nk.storageRead([
    { collection: "matches", key: "waiting", userId: SYSTEM_USER_ID },
  ]);

  // Lấy mảng ids hiện có (nếu có)
  let waiting: string[] = [];
  if (res && res.length > 0 && res[0].value && res[0].value.ids && res[0].value.ids.length) {
    waiting = res[0].value.ids as string[];
  }

  // Tạo mảng mới: [matchId, ...waiting].slice(0, 3) — nhưng viết theo ES5
  const newWaiting: string[] = [matchId];
  for (let i = 0; i < waiting.length && newWaiting.length < 3; i++) {
    newWaiting.push(waiting[i]);
  }

  nk.storageWrite([
    {
      collection: "matches",
      key: "waiting",
      userId: SYSTEM_USER_ID,
      value: { ids: newWaiting },
    },
  ]);
}


//  Đọc danh sách match đang chờ
function getWaitingMatches(nk: nkruntime.Nakama): string[] {
  const data = nk.storageRead([
    { collection: "matches", key: "waiting", userId: SYSTEM_USER_ID },
  ]);

  if (!data || data.length === 0 || !data[0].value || !data[0].value.ids) {
    return [];
  }

  return data[0].value.ids as string[];
}

// RPC: get_waiting_match
function get_waiting_match(ctx, logger, nk, payload): string {
  const waitingMatches = getWaitingMatches(nk);

  for (let i = 0; i < waitingMatches.length; i++) {
    const id = waitingMatches[i];
    
      const info = nk.matchGet(id);
      if (info) {
        return id;
      }
    
  }

  // Không có match nào → tạo mới
  const newMatchId = nk.matchCreate("flabby_bird_match");
  addWaitingMatch(nk, newMatchId);

  return newMatchId;
}




//  INIT MODULE
function InitModule(  ctx: nkruntime.Context,  logger: nkruntime.Logger,  nk: nkruntime.Nakama,  initializer: nkruntime.Initializer) {
  initializer.registerMatch("flabby_bird_match", {
  matchInit: matchInit,
  matchJoinAttempt: matchJoinAttempt,
  matchJoin: matchJoin,
  matchLoop: matchLoop,
  matchLeave: matchLeave,
  matchTerminate: matchTerminate,
  matchSignal: matchSignal,
});

  initializer.registerRpc("get_waiting_match", get_waiting_match);

  logger.info("✅ Flabby Bird Match loaded successfully.");
}
