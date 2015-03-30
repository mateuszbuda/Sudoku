//
//  ViewController.swift
//  Sudoku
//
//  Created by Mateusz Buda on 04/03/15.
//  Copyright (c) 2015 Mateusz Buda. All rights reserved.
//

import UIKit
import Metal
import QuartzCore
import Darwin
import Accelerate

let N = 9;
let BOARD_SZ = N * N;

class ViewController: UIViewController, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var gpuSwitch: UISwitch!
    
    var board = [Int32](count: 81, repeatedValue: 0)

    override func viewDidLoad() {
        super.viewDidLoad()
        board =
            [1, 0, 0, 0, 0, 8, 4, 6, 7,
             2, 8, 0, 0, 4, 6, 9, 5, 1,
             9, 4, 6, 0, 1, 5, 3, 2, 8,
             4, 1, 9, 0, 0, 7, 2, 0, 6,
             3, 0, 0, 6, 2, 4, 1, 0, 5,
             6, 0, 2, 0, 0, 1, 7, 0, 4,
             8, 6, 3, 4, 7, 9, 5, 1, 2,
             7, 2, 1, 8, 5, 3, 6, 4, 9,
             5, 9, 4, 1, 6, 2, 8, 7, 3]
        
        gpuSwitch.on = true
        label.text = gpuSwitch.on ? "GPU" : "CPU"
        gpuSwitch.addTarget(self, action: Selector("stateChanged:"), forControlEvents: UIControlEvents.ValueChanged)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func stateChanged(switchState: UISwitch) {
        label.text = gpuSwitch.on ? "GPU" : "CPU"
    }

    // MARK: - UICollectionView
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return board.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("cell", forIndexPath: indexPath) as CollectionCell
        cell.textField.text = "\(board[indexPath.row])"
        return cell
    }
    
    // MARK: - UIActions
    @IBAction func solve(sender: UIButton) {
        if (gpuSwitch.on) {
            // initialize Metal
            var (device, commandQueue, defaultLibrary, commandBuffer, computeCommandEncoder) = initMetal()
            
            // set up a compute pipeline with sudokuSolver function and add it to encoder
            let sudokuSolver = defaultLibrary.newFunctionWithName("sudokuSolver")
            var pipelineErrors: NSError?
            var computePipelineState = device.newComputePipelineStateWithFunction(sudokuSolver!, error: &pipelineErrors)
            if computePipelineState == nil {
                println("Failed to create pipeline state, error: \(pipelineErrors?.debugDescription)")
                computeCommandEncoder.endEncoding()
                return
            }
            computeCommandEncoder.setComputePipelineState(computePipelineState!)
            
            // calculate byte length of input data - board
            var boardByteLength = board.count * sizeofValue(board[0])
            
            // create a MTLBuffer - input data for GPU
            var boardBuffer = device.newBufferWithBytes(&board, length: boardByteLength, options: nil)
            
            // set the input vector for the sudokuSolver function,
            // atIndex: 0 here corresponds to buffer(0) in the sudokuSolver function
            computeCommandEncoder.setBuffer(boardBuffer, offset: 0, atIndex: 0)
            
            // create the output vector for the sudokuSolver function,
            // atIndex: 2 here corresponds to buffer(2) in the sudokuSolver function
            var result = [Int32](count:board.count, repeatedValue: 0)
            var resultBuffer = device.newBufferWithBytes(&result, length: boardByteLength, options: nil)
            computeCommandEncoder.setBuffer(resultBuffer, offset: 0, atIndex: 2)
            
            var solvedFlag = [Int32](count: 1, repeatedValue: 0)
            var solvedFlagBuffer = device.newBufferWithBytes(&solvedFlag, length: sizeofValue(solvedFlag[0]), options: nil)
            computeCommandEncoder.setBuffer(solvedFlagBuffer, offset: 0, atIndex: 1)
            
            var random = [ UInt32(arc4random_uniform(UInt32.max)) ]
            var randomBuffer = device.newBufferWithBytes(&random, length: sizeofValue(random[0]), options: nil)
            computeCommandEncoder.setBuffer(randomBuffer, offset: 0, atIndex: 3)
            
            // make grid
            var threadsPerGroup = MTLSize(width: 16, height: 1, depth: 1)
            var numThreadgroups = MTLSize(width: (Int)(pow(Double(2), Double(2))), height: 1, depth:1)
            println("Block: \(threadsPerGroup.width) x \(threadsPerGroup.height)\nGrid: \(numThreadgroups.width) x \(numThreadgroups.height) x \(numThreadgroups.depth)")
            computeCommandEncoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
            
            // compute and wait for result
            computeCommandEncoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            if (commandBuffer.error != nil) {
                println("Command buffer error: \(commandBuffer.error?.debugDescription)")
            }
            
            // Get GPU data
            // resultBuffer.contents() returns UnsafeMutablePointer roughly equivalent to char* in C
            var data = NSData(bytesNoCopy: resultBuffer.contents(),
                length: boardByteLength, freeWhenDone: false)
            
            // get data from GPU into Swift array
            data.getBytes(&board, length: board.count * sizeof(Int32))
            
            var data2 = NSData(bytesNoCopy: solvedFlagBuffer.contents(),
                length: sizeofValue(solvedFlag[0]), freeWhenDone: false)
            data2.getBytes(&solvedFlag, length: sizeofValue(solvedFlag))
            println("Solved: \(solvedFlag[0])")
        }
        else {
            board = sudokuSolver(board);
        }
        
        collectionView.reloadData()
    }
    
    @IBAction func reset(sender: UIButton) {
        board =
            [1, 0, 0, 0, 0, 8, 4, 6, 7,
             2, 8, 0, 0, 4, 6, 9, 5, 1,
             9, 4, 6, 7, 1, 5, 3, 2, 8,
             4, 1, 9, 0, 0, 7, 2, 0, 6,
             3, 0, 0, 6, 2, 4, 1, 0, 5,
             6, 0, 2, 0, 0, 1, 7, 0, 4,
             8, 0, 3, 0, 7, 0, 5, 0, 2,
             7, 2, 0, 8, 0, 3, 6, 4, 9,
             5, 0, 4, 0, 6, 0, 8, 7, 3]
        
        collectionView.reloadData()
    }
    
    // MARK: - Metal
    
    func initMetal() -> (MTLDevice, MTLCommandQueue, MTLLibrary, MTLCommandBuffer, MTLComputeCommandEncoder) {
            // Get access to iPhone or iPad GPU
            var device = MTLCreateSystemDefaultDevice()
            
            // Queue to handle an ordered list of command buffers
            var commandQueue = device.newCommandQueue()
            
            // Access to Metal functions that are stored in Kernel.metal file, e.g. sukoduSolver()
            var defaultLibrary = device.newDefaultLibrary()
            
            // Buffer for storing encoded commands that are sent to GPU
            var commandBuffer = commandQueue.commandBuffer()
            
            // Encoder for GPU commands
            var computeCommandEncoder = commandBuffer.computeCommandEncoder()
            
            return (device, commandQueue, defaultLibrary!, commandBuffer, computeCommandEncoder)
    }
    
    
    // MARK: - CPU Sudoku Solver
    
    func sudokuSolver(board: [Int32]) -> ([Int32]) {
        var permutations = [Int32](count: 81, repeatedValue: 0)
        
        for (var i: Int = 0; i < BOARD_SZ; ++i) {
            if (board[i] != 0) {
                permutations[i] = board[i];
            }
        }

        for (var i = 0; i < BOARD_SZ; ++i) {
            if (board[i] == 0) {
                var v: Int;
                for (v = 1; v < N; ++v) {
                    var unique = true;
                    for (var j = 0; j < N; ++j) {
                        if (Int(permutations[(i / N) * N + j]) == v) {
                            unique = false;
                            break;
                        }
                    }
                    if (unique) {
                        break;
                    }
                }
                permutations[i] = Int32(v);
            }
        }
        
        var solved = false;
        while (!solved) {
            
            // random permutations in rows
            for (var j = 0; j < N; ++j) {
                for (var k = 0; k < N; ++k) {
                    let p = (j * N) + k;
                    if (board[p] == 0) {
                        let l = (j * N) + (Int(arc4random_uniform(UInt32.max)) % N);
                        if (board[l] == 0 && l != p) {
                            let tmp = permutations[p];
                            permutations[p] = permutations[l];
                            permutations[l] = tmp;
                        }
                    }
                }
            }

            
            // verify solution
            var valid = true;

            // verify columns
            for (var j = 0; j < N; ++j) {
                for (var k = 0; k < (N - 1); ++k) {
                    for (var l = (k + 1); l < N; ++l) {
                        if (permutations[j + (k * N)] == permutations[j + (l * N)]) {
                            valid = false;
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
                var j = 0;
                while (j < BOARD_SZ) {
                    var box = [Int32](count: N, repeatedValue: 0)

                    box[0] = permutations[j];
                    box[1] = permutations[j+1];
                    box[2] = permutations[j+2];
                    box[3] = permutations[j+N];
                    box[4] = permutations[j+N+1];
                    box[5] = permutations[j+N+2];
                    box[6] = permutations[j+N+N];
                    box[7] = permutations[j+N+N+1];
                    box[8] = permutations[j+N+N+2];

                    for (var p = 0; p < (N - 1); ++p) {
                        for (var q = (p + 1); q < N; ++q) {
                            if (box[p] == box[q]) {
                                valid = false;
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
            }
            
            if (valid) {
                solved = true;
            }
            
        }

        return permutations
    }
}
