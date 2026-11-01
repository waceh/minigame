/* Pure puzzle logic, also loadable by Node for verification. */
(function (root) {
    'use strict';
    const peers = (a, b) => Math.floor(a / 9) === Math.floor(b / 9) || a % 9 === b % 9 ||
        (Math.floor(a / 27) === Math.floor(b / 27) && Math.floor(a % 9 / 3) === Math.floor(b % 9 / 3));
    function shuffle(values) {
        for (let i = values.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [values[i], values[j]] = [values[j], values[i]];
        }
        return values;
    }
    function countSolutions(input, limit = 2) {
        const board = input.slice();
        function search() {
            let best = -1, options = [];
            for (let i = 0; i < 81; i++) {
                if (board[i]) continue;
                const candidates = [1,2,3,4,5,6,7,8,9].filter(n => !board.some((v, j) => v === n && peers(i, j)));
                if (!candidates.length) return 0;
                if (best < 0 || candidates.length < options.length) { best = i; options = candidates; }
                if (options.length === 1) break;
            }
            if (best < 0) return 1;
            let count = 0;
            for (const n of options) {
                board[best] = n;
                count += search();
                if (count >= limit) break;
            }
            board[best] = 0;
            return Math.min(count, limit);
        }
        if (board.some((n, i) => n && board.some((v, j) => i !== j && v === n && peers(i, j)))) return 0;
        return search();
    }
    function generate(difficulty) {
        const order = () => shuffle([0,1,2]).flatMap(group => shuffle([0,1,2]).map(n => group * 3 + n));
        const rows = order(), cols = order(), digits = shuffle([1,2,3,4,5,6,7,8,9]);
        const solution = rows.flatMap(r => cols.map(c => digits[(r * 3 + Math.floor(r / 3) + c) % 9]));
        const puzzle = solution.slice(), target = { easy: 42, normal: 34, hard: 28 }[difficulty] || 34;
        let clues = 81;
        for (const i of shuffle(Array.from({ length: 81 }, (_, n) => n))) {
            const old = puzzle[i];
            puzzle[i] = 0;
            if (countSolutions(puzzle) !== 1) puzzle[i] = old;
            else clues--;
            if (clues <= target) break;
        }
        return { puzzle, solution };
    }
    const api = { peers, countSolutions, generate };
    if (typeof module !== 'undefined') module.exports = api;
    else root.SudokuEngine = api;
})(globalThis);
