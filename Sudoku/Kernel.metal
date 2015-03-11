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
    
    for (int i = 0; i < BOARD_SZ; ++i) {
        
    }
    
    while (!solved) {
        for (int i = 0; i < LOOP; ++i) {
            
            // generate permutations
            for (int j = 0; j < N; ++j) {
                int m = (j * N) + (rand() % N);
                int n = (j * N) + (rand() % N);
                if (permutations[m] != 0 && permutations[n] != 0) {
                    swap(permutations[m], permutations[n])
                }
            }
            
            for (int i = 0; i < BOARD_SZ; i++) {
                if (boardCopy[i] == 0) {
                    
                }
            }
            // verify solution
            
            // if valid { solved = true; }
        }
    }
}
