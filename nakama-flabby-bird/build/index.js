var MatchPhase;
(function (MatchPhase) {
    MatchPhase["WaitingForPlayers"] = "waiting";
    MatchPhase["Countdown"] = "countdown";
    MatchPhase["Playing"] = "playing";
    MatchPhase["Finished"] = "finished";
})(MatchPhase || (MatchPhase = {}));
var OpCode;
(function (OpCode) {
    OpCode[OpCode["LOBBY_UPDATE"] = 200] = "LOBBY_UPDATE";
    OpCode[OpCode["COUNTDOWN"] = 100] = "COUNTDOWN";
    OpCode[OpCode["START_GAME"] = 101] = "START_GAME";
    OpCode[OpCode["GAME_FINISHED"] = 102] = "GAME_FINISHED";
    OpCode[OpCode["PLAYER_FLAP"] = 201] = "PLAYER_FLAP";
    OpCode[OpCode["PLAYER_DIED"] = 202] = "PLAYER_DIED";
    OpCode[OpCode["PLAYER_SCORED"] = 203] = "PLAYER_SCORED";
    OpCode[OpCode["PIPE_SPAWN"] = 204] = "PIPE_SPAWN";
})(OpCode || (OpCode = {}));
var matchInit = function (ctx, logger, nk, params) {
    var state = {
        players: {},
        presences: [],
        currentPhase: MatchPhase.WaitingForPlayers,
        countdownValue: 3,
        gameStartTime: 0,
        winner: null,
        pipes: [],
        nextPipeId: 1,
        cleanedUp: false,
        finishTickCounter: 0,
        pipeTimer: 0,
        elapsedTime: 0,
    };
    return {
        state: state,
        tickRate: 30,
        label: "Multiplayer Flabby Bird",
    };
};
var matchJoinAttempt = function (ctx, logger, nk, dispatcher, tick, state, presence, metadata) {
    if (state.currentPhase === MatchPhase.Finished) {
        return { state: state, accept: false, rejectMessage: "Match already finished." };
    }
    return { state: state, accept: true };
};
var matchJoin = function (ctx, logger, nk, dispatcher, tick, state, presences) {
    for (var _i = 0, presences_1 = presences; _i < presences_1.length; _i++) {
        var p = presences_1[_i];
        if (state.players[p.userId])
            continue;
        state.players[p.userId] = {
            presence: p,
            username: p.username,
            birdY: 300,
            velocity: 0,
            isAlive: true,
            score: 0,
            isInLobby: false,
        };
        state.presences.push(p);
        dispatcher.broadcastMessage(110, JSON.stringify({
            event: "player_joined",
            username: p.username,
            totalPlayers: Object.keys(state.players).length,
        }), state.presences);
    }
    return { state: state };
};
function spawnPipe(state) {
    var id = state.nextPipeId++;
    var gapY = Math.floor(Math.random() * 550) + 200;
    return { id: id, gapY: gapY };
}
var matchLoop = function (ctx, logger, nk, dispatcher, tick, state, messages) {
    switch (state.currentPhase) {
        case MatchPhase.WaitingForPlayers: {
            for (var _i = 0, messages_1 = messages; _i < messages_1.length; _i++) {
                var msg = messages_1[_i];
                if (msg.opCode !== OpCode.LOBBY_UPDATE)
                    continue;
                var uid = msg.sender.userId;
                var player = state.players[uid];
                if (!player)
                    continue;
                player.isInLobby = true;
                var playersList = [];
                for (var id in state.players) {
                    var pl = state.players[id];
                    playersList.push({
                        userId: id,
                        username: pl.username,
                        isInLobby: pl.isInLobby,
                        isAlive: pl.isAlive,
                        score: pl.score,
                    });
                }
                dispatcher.broadcastMessage(OpCode.LOBBY_UPDATE, JSON.stringify({
                    event: "lobby_update",
                    players: playersList,
                }), state.presences);
            }
            var readyCount = 0;
            for (var _a = 0, _b = state.presences; _a < _b.length; _a++) {
                var p = _b[_a];
                var pl = state.players[p.userId];
                if (pl && pl.isInLobby)
                    readyCount++;
            }
            if (readyCount >= 2) {
                state.currentPhase = MatchPhase.Countdown;
                state.countdownValue = 3;
            }
            break;
        }
        case MatchPhase.Countdown: {
            if (tick % 30 === 0) {
                state.countdownValue -= 1;
                dispatcher.broadcastMessage(OpCode.COUNTDOWN, JSON.stringify({ event: "countdown", value: state.countdownValue }), state.presences);
            }
            if (state.countdownValue <= 0) {
                state.currentPhase = MatchPhase.Playing;
                state.gameStartTime = Date.now();
                dispatcher.broadcastMessage(OpCode.START_GAME, JSON.stringify({ event: "start_game" }), state.presences);
            }
            break;
        }
        case MatchPhase.Playing: {
            var S = state;
            for (var _c = 0, messages_2 = messages; _c < messages_2.length; _c++) {
                var msg = messages_2[_c];
                if (msg.opCode === OpCode.LOBBY_UPDATE) {
                    var data = JSON.parse(nk.binaryToString(msg.data));
                    if (data.event === "sync_request") {
                        var playersArr = [];
                        for (var id in state.players) {
                            var pl = state.players[id];
                            playersArr.push({
                                userId: id,
                                username: pl.username,
                                birdY: pl.birdY,
                                velocity: pl.velocity,
                                isAlive: pl.isAlive,
                                score: pl.score,
                            });
                        }
                        dispatcher.broadcastMessage(OpCode.LOBBY_UPDATE, JSON.stringify({ event: "lobby_update", players: playersArr }), state.presences);
                    }
                }
                switch (msg.opCode) {
                    case OpCode.PLAYER_FLAP: {
                        var data = JSON.parse(nk.binaryToString(msg.data));
                        var pl = state.players[msg.sender.userId];
                        if (!pl || !pl.isAlive)
                            break;
                        pl.birdY = data.y;
                        pl.velocity = data.velocity;
                        dispatcher.broadcastMessage(OpCode.PLAYER_FLAP, JSON.stringify({
                            userId: msg.sender.userId,
                            y: pl.birdY,
                            velocity: pl.velocity,
                        }), state.presences);
                        break;
                    }
                    case OpCode.PLAYER_DIED: {
                        var pl = state.players[msg.sender.userId];
                        if (!pl)
                            break;
                        pl.isAlive = false;
                        dispatcher.broadcastMessage(OpCode.PLAYER_DIED, JSON.stringify({ userId: msg.sender.userId }), state.presences);
                        var aliveCount = 0;
                        for (var id in state.players) {
                            var p = state.players[id];
                            if (p && p.isAlive)
                                aliveCount++;
                        }
                        if (aliveCount > 0)
                            break;
                        var winnerId = "";
                        var best = null;
                        for (var id in state.players) {
                            var p = state.players[id];
                            if (!best || p.score > best.score) {
                                best = p;
                                winnerId = id;
                            }
                        }
                        var winnerName = best ? best.username : "";
                        state.currentPhase = MatchPhase.Finished;
                        dispatcher.broadcastMessage(OpCode.GAME_FINISHED, JSON.stringify({
                            event: "game_finished",
                            winner: winnerName,
                            winnerId: winnerId,
                        }), state.presences);
                        return { state: state };
                    }
                    case OpCode.PLAYER_SCORED: {
                        var pl = state.players[msg.sender.userId];
                        if (!pl || !pl.isAlive)
                            break;
                        pl.score += 1;
                        dispatcher.broadcastMessage(OpCode.PLAYER_SCORED, JSON.stringify({
                            userId: msg.sender.userId,
                            score: pl.score,
                        }), state.presences);
                        break;
                    }
                }
            }
            if (!S.nextPipeId)
                S.nextPipeId = 1;
            if (!S.pipes)
                S.pipes = [];
            var pipeSpeed = 150;
            var tickDelta = 1 / 30;
            var pipeInterval = 2;
            var pipeSpacing = pipeSpeed * pipeInterval;
            var screenWidth = 700;
            var startX = screenWidth;
            for (var _d = 0, _e = S.pipes; _d < _e.length; _d++) {
                var pipe = _e[_d];
                pipe.x -= pipeSpeed * tickDelta;
            }
            S.pipes = S.pipes.filter(function (p) { return p.x > -100; });
            var lastPipe = S.pipes[S.pipes.length - 1];
            var shouldSpawn = !lastPipe || lastPipe.x <= startX - pipeSpacing;
            if (shouldSpawn) {
                var _f = spawnPipe(S), id = _f.id, gapY = _f.gapY;
                var x = startX;
                S.pipes.push({ id: id, x: x, gapY: gapY });
                dispatcher.broadcastMessage(OpCode.PIPE_SPAWN, JSON.stringify({
                    id: id,
                    x: x,
                    gapY: gapY,
                    serverTime: Date.now(),
                }), S.presences);
            }
            break;
        }
        case MatchPhase.Finished: {
            if (!state.cleanedUp) {
                removeWaitingMatch(nk, ctx.matchId);
                state.cleanedUp = true;
            }
            state.finishTickCounter = (state.finishTickCounter || 0) + 1;
            if (state.finishTickCounter >= 90)
                return null;
            return { state: state };
        }
    }
    return { state: state };
};
function removeWaitingMatch(nk, matchId) {
    var data = nk.storageRead([
        { collection: "matches", key: "waiting", userId: SYSTEM_USER_ID },
    ]);
    if (!data || data.length === 0)
        return;
    var current = data[0].value;
    if (!current || !current.ids || !Array.isArray(current.ids))
        return;
    var updatedIds = [];
    for (var _i = 0, _a = current.ids; _i < _a.length; _i++) {
        var id = _a[_i];
        if (id !== matchId)
            updatedIds.push(id);
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
var matchLeave = function (ctx, logger, nk, dispatcher, tick, state, presences) {
    for (var _i = 0, presences_2 = presences; _i < presences_2.length; _i++) {
        var p = presences_2[_i];
        delete state.players[p.userId];
        var newPresences = [];
        for (var _a = 0, _b = state.presences; _a < _b.length; _a++) {
            var pr = _b[_a];
            if (pr.userId !== p.userId)
                newPresences.push(pr);
        }
        state.presences = newPresences;
        var totalPlayers = 0;
        for (var _ in state.players)
            totalPlayers++;
        dispatcher.broadcastMessage(111, JSON.stringify({
            event: "player_left",
            username: p.username,
            totalPlayers: totalPlayers,
        }), state.presences);
    }
    var remaining = 0;
    for (var _ in state.players)
        remaining++;
    if (remaining === 0 && state.currentPhase !== MatchPhase.Finished) {
        state.currentPhase = MatchPhase.Finished;
    }
    return { state: state };
};
var matchSignal = function (ctx, logger, nk, dispatcher, tick, state, data) {
    return { state: state };
};
var matchTerminate = function (ctx, logger, nk, dispatcher, tick, state, graceSeconds) {
    if (ctx.matchId) {
        nk.matchCreate("flabby_bird_match");
    }
    return { state: state };
};
var SYSTEM_USER_ID = "00000000-0000-0000-0000-000000000000";
function addWaitingMatch(nk, matchId) {
    var res = nk.storageRead([
        { collection: "matches", key: "waiting", userId: SYSTEM_USER_ID },
    ]);
    var waiting = [];
    if (res && res.length > 0 && res[0].value && res[0].value.ids && res[0].value.ids.length) {
        waiting = res[0].value.ids;
    }
    var newWaiting = [matchId];
    for (var i = 0; i < waiting.length && newWaiting.length < 3; i++) {
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
function getWaitingMatches(nk) {
    var data = nk.storageRead([
        { collection: "matches", key: "waiting", userId: SYSTEM_USER_ID },
    ]);
    if (!data || data.length === 0 || !data[0].value || !data[0].value.ids) {
        return [];
    }
    return data[0].value.ids;
}
function get_waiting_match(ctx, logger, nk, payload) {
    var waitingMatches = getWaitingMatches(nk);
    for (var i = 0; i < waitingMatches.length; i++) {
        var id = waitingMatches[i];
        var info = nk.matchGet(id);
        if (info) {
            return id;
        }
    }
    var newMatchId = nk.matchCreate("flabby_bird_match");
    addWaitingMatch(nk, newMatchId);
    return newMatchId;
}
function InitModule(ctx, logger, nk, initializer) {
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
