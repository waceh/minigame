const { test } = require('node:test');
const assert = require('node:assert/strict');
const { generate, countSolutions, peers } = require('./engine.js');

for (const [difficulty, minimum] of Object.entries({ easy: 42, normal: 34, hard: 28 })) {
    test(`${difficulty}: generated puzzles have one valid solution and preserve clues`, () => {
        for (let sample = 0; sample < 10; sample++) {
            const { puzzle, solution } = generate(difficulty);
            assert.equal(puzzle.length, 81);
            assert.equal(solution.length, 81);
            assert.equal(countSolutions(puzzle), 1);
            assert(puzzle.filter(Boolean).length >= minimum);
            assert(puzzle.includes(0));
            solution.forEach((n, i) => {
                assert(Number.isInteger(n) && n >= 1 && n <= 9);
                assert(!puzzle[i] || puzzle[i] === n);
                assert(!solution.some((v, j) => i !== j && peers(i, j) && v === n));
            });
        }
    });
}

test('solver distinguishes contradictory, multiple and complete solutions without mutating input', () => {
    const empty = Array(81).fill(0);
    assert.equal(countSolutions(empty), 2);
    assert.deepEqual(empty, Array(81).fill(0));
    const conflict = empty.slice(); conflict[0] = conflict[1] = 1;
    assert.equal(countSolutions(conflict), 0);
    const { solution } = generate('easy');
    assert.equal(countSolutions(solution), 1);
});
