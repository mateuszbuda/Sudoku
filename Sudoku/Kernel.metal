//
//  Kernel.metal
//  Sudoku
//
//  Created by Mateusz Buda on 05/03/15.
//  Copyright (c) 2015 Mateusz Buda. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#define LENGTH(x) ((sizeof(x)/sizeof(0[x])) / ((size_t)(!(sizeof(x) % sizeof(0[x])))))
#define swap(x,y) { x = x + y; y = x - y; x = x - y; }

constant static const int N = 9;
constant static const int BOARD_SZ = N * N;
constant static const int LOOP = 1000000;

kernel void sudokuSolver(const device int *board [[ buffer(0) ]],
                         device bool *solved [[ buffer(1) ]]) {
    thread int boardCopy[BOARD_SZ];
    thread int permutations[BOARD_SZ];
    
    // copy board to faster memory
    for (int i = 0; i < BOARD_SZ; ++i) {
        boardCopy[i] = board[i];
    }
    
    for (int i = 0, int v = 0; i < BOARD_SZ; ++i) {
        if (boardCopy[i] == 0) {
            for (int j = 0; j < N; ++j) {
                if (boardCopy[(i / N) + j] == (v + 1)) {
                    --i;
                    break;
                }
                permutations[i] = (v + 1);
            }
            v = (v + 1) % N;
        }
        else {
            permutations[i] = boardCopy[i];
        }
    }
    
    while (!solved) {
        for (int i = 0; i < LOOP; ++i) {
            
            // random permutations in rows
            for (int j = 0; j < N; ++j) {
                for (int k = 0; k < (N - 1); ++k) {
                    if (boardCopy[(j * N) + k] == 0) {
                        int l = (j * N) + k + 1 + (rand() % (N - k));
                        if (boardCopy[l] == 0) {
                            swap(permutations[k], permutations[l])
                        }
                    }
                }
            }
            
            // verify solution
            
            
            // if valid { solved = true; }
        }
    }
}
