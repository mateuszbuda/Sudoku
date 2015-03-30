//
//  Kernel.metal
//  Sudoku
//
//  Created by Mateusz Buda on 05/03/15.
//  Copyright (c) 2015 Mateusz Buda. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;


uint myRand(uint, uint);

constant const int N = 9;
constant const int BOARD_SZ = N * N;

// (kernel | vertex | fragment)
kernel void sudokuSolver(const device int *board [[ buffer(0) ]],
                         device int *solved [[ buffer(1) ]],
                         device int *result [[ buffer(2) ]],
                         device uint *random [[ buffer(3) ]],
                         uint id [[ thread_position_in_grid ]]) {
    
    thread int boardCopy[BOARD_SZ];
    thread int permutations[BOARD_SZ];
    thread uint rand = random[0];
    
    // copy board to faster memory
    for (int i = 0; i < BOARD_SZ; ++i) {
        boardCopy[i] = board[i];
        permutations[i] = boardCopy[i];
//        result[i] = boardCopy[i];
    }
    
    // initial permutation
    for (int i = 0; i < BOARD_SZ; ++i) {
        if (boardCopy[i] == 0) {
            int v;
            for (v = 1; v < N; ++v) {
                bool unique = true;
                for (int j = 0; j < N; ++j) {
                    if (permutations[(i / N) * N + j] == v) {
                        unique = false;
                        break;
                    }
                }
                if (unique) {
                    break;
                }
            }
            permutations[i] = v;
        }
    }

    // solve sudoku
    while (solved[0] == 0) {

        // random permutations in rows
        for (int j = 0; j < N; ++j) {
            for (int k = 0; k < N; ++k) {
                int p = (j * N) + k;
                if (boardCopy[p] == 0) {
                    rand = myRand(id, rand);
                    int l = (j * N) + (rand % N);
                    if (boardCopy[l] == 0 && l != p) {
                        int tmp = permutations[p];
                        permutations[p] = permutations[l];
                        permutations[l] = tmp;
                    }
                }
            }
        }


        // verify solution
        bool valid = true;

        // verify columns
        for (int j = 0; j < N; ++j) {
            for (int k = 0; k < (N - 1); ++k) {
                for (int l = (k + 1); l < N; ++l) {
                    int s = j + (k * N);
                    int t = j + (l * N);
                    if (permutations[s] == permutations[t]) {
//                        valid = false;
                        break;
                    }
                }
                if (!valid) {
                    break;
                }
            }
            if (!valid) {
                break;
            }
        }

        // verify boxes
        if (valid) {
            int j = 0;
            while (j < BOARD_SZ) {
                int box[N];
                
                box[0] = permutations[j];
                box[1] = permutations[j+1];
                box[2] = permutations[j+2];
                box[3] = permutations[j+N];
                box[4] = permutations[j+N+1];
                box[5] = permutations[j+N+2];
                box[6] = permutations[j+N+N];
                box[7] = permutations[j+N+N+1];
                box[8] = permutations[j+N+N+2];
                
                for (int p = 0; p < (N - 1); ++p) {
                    for (int q = (p + 1); q < N; ++q) {
                        if (box[p] == box[q]) {
//                            valid = false;
                            break;
                        }
                    }
                    if (!valid) {
                        break;
                    }
                }
                if (!valid) {
                    break;
                }
                
                j = j + 3;
                if ((j % N) == 0) {
                    j = j + (2 * N);
                }
            }
        } // if (valid)
        else {
            continue;
        }
        
        if (valid) {
            solved[0] = 1;
            for (int x = 0; x < BOARD_SZ; ++x) {
                result[x] = permutations[x];
            }
        }

    } // while (!(solved[0] == 0))
}

inline uint myRand(uint id, uint rand) {
    uint32_t state = id * 13 + rand;
    state = state * 1664525 + 1013904223;
    return state >> 24;
}