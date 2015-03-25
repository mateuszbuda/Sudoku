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

uint myRand(uint, uint);

constant static const int N = 9;
constant static const int BOARD_SZ = N * N;
constant static const int LOOP = 1000000;

kernel void sudokuSolver(const device int *board [[ buffer(0) ]],
                         device bool *solved [[ buffer(1) ]],
                         device int *result [[ buffer(2) ]],
                         device uint *random [[ buffer(3) ]],
                         uint id [[ thread_position_in_grid ]]) {
    
    thread int boardCopy[BOARD_SZ];
    thread int permutations[BOARD_SZ];
    thread int rand = *random;
    
    // copy board to faster memory
    for (int i = 0; i < BOARD_SZ; ++i) {
        boardCopy[i] = board[i];
        if (boardCopy[i] != 0) {
            permutations[i] = boardCopy[i];
        }
    }
    
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

    if (id == 0) {
        for (int j = 0; j < N; ++j) {
            for (int k = 0; k < N; ++k) {
                int p = (j * N) + k;
                if (boardCopy[p] == 0) {
                    int l = (j * N) + (myRand(id, rand) % N);
                    if (boardCopy[l] == 0 && l != p) {
                        int tmp = permutations[p];
                        permutations[p] = permutations[l];
                        permutations[l] = tmp;
                    }
                }
            }
        }
        for (int x = 0; x < BOARD_SZ; ++x) {
            result[x] = permutations[x];
        }
    }
    
//    while (!(*solved)) {
//        for (int i = 0; i < LOOP; ++i) {
//            
//            // random permutations in rows
//            for (int j = 0; j < N; ++j) {
//                for (int k = 0; k < (N - 1); ++k) {
//                    if (boardCopy[(j * N) + k] == 0) {
//                        int l = (j * N) + k + 1 + (myRand() % (N - k));
//                        if (boardCopy[l] == 0) {
//                            swap(permutations[k], permutations[l])
//                        }
//                    }
//                }
//            }
//            
//            bool valid = true;
//            // verify solution
//            
//            // verify columns
//            for (int j = 0; j < N; ++j) {
//                for (int k = 0; k < (N - 1); ++k) {
//                    for (int l = (k + 1); l < N; ++l) {
//                        if (permutations[j + (k * N)] == permutations[j + ((k + l) * N)]) {
//                            valid = false;
//                            break;
//                        }
//                    }
//                    if (!valid) {
//                        break;
//                    }
//                }
//                if (!valid) {
//                    break;
//                }
//            }
//            
//            // verify boxes
//            if (valid) {
//                int j = 0;
//                while (j < BOARD_SZ) {
//                    int box[N];
//                    
//                    box[0] = permutations[j];
//                    box[1] = permutations[j+1];
//                    box[2] = permutations[j+2];
//                    box[3] = permutations[j+N];
//                    box[4] = permutations[j+N+1];
//                    box[5] = permutations[j+N+2];
//                    box[6] = permutations[j+N+N];
//                    box[7] = permutations[j+N+N+1];
//                    box[8] = permutations[j+N+N+2];
//                    
//                    for (int p = 0; p < (N - 1); ++p) {
//                        for (int q = (p + 1); q < N; ++q) {
//                            if (box[p] == box[q]) {
//                                valid = false;
//                                break;
//                            }
//                        }
//                        if (!valid) {
//                            break;
//                        }
//                    }
//                    
//                    j = j + 3;
//                    if ((j % N) == 0) {
//                        j = j + (2 * N);
//                    }
//                }
//            }
//            
//            if (valid) {
//                (*solved) = true;
//                for (int x = 0; x < BOARD_SZ; ++x) {
//                    result[x] = permutations[x];
//                }
//            }
//        }
//    }
}

inline uint myRand(uint id, uint rand)
{
    thread uint32_t state = id * 13 + rand;
    state = state * 1664525 + 1013904223;
    return state >> 24;
}
