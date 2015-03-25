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
            [1, 0, 0, 0, 0, 8, 4, 6, 0,
             2, 8, 0, 0, 4, 6, 9, 0, 0,
             0, 0, 0, 0, 1, 5, 0, 2, 8,
             4, 0, 9, 0, 0, 0, 2, 0, 6,
             3, 0, 0, 0, 2, 0, 0, 0, 5,
             6, 0, 2, 0, 0, 0, 7, 0, 4,
             8, 6, 0, 4, 7, 0, 0, 0, 2,
             0, 0, 1, 8, 5, 0, 0, 4, 9,
             0, 9, 4, 1, 0, 0, 0, 0, 3]
        
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
//        var cells = collectionView.visibleCells();
//        for (var i = 0; i < 81; ++i) {
//            board[i] = (Int32)((cells[i] as CollectionCell).textField.text.toInt()!);
//        }
        if (gpuSwitch.on) {
            // initialize Metal
            var (device, commandQueue, defaultLibrary, commandBuffer, computeCommandEncoder) = initMetal()
            
            // set up a compute pipeline with sudokuSolver function and add it to encoder
            let sudokuSolver = defaultLibrary.newFunctionWithName("sudokuSolver")
            var pipelineErrors: NSError?
            var computePipelineFilter = device.newComputePipelineStateWithFunction(sudokuSolver!, error: &pipelineErrors)
            if computePipelineFilter == nil {
                println("Failed to create pipeline state, error: \(pipelineErrors?.debugDescription)")
                computeCommandEncoder.endEncoding()
                return
            }
            computeCommandEncoder.setComputePipelineState(computePipelineFilter!)
            
            // calculate byte length of input data - board
            var boardByteLength = board.count * sizeofValue(board[0])
            
            // create a MTLBuffer - input data for GPU
            var boardBuffer = device.newBufferWithBytes(&board, length: boardByteLength, options: nil)
            
            // set the input vector for the sudokuSolver function, e.g. inVector
            // atIndex: 0 here corresponds to buffer(0) in the sudokuSolver function
            computeCommandEncoder.setBuffer(boardBuffer, offset: 0, atIndex: 0)
            
            // create the output vector for the sudokuSolver function, e.g. outVector
            // atIndex: 2 here corresponds to buffer(2) in the sudokuSolver function
            var result = [Int32](count:board.count, repeatedValue: 0)
            var resultBuffer = device.newBufferWithBytes(&result, length: boardByteLength, options: nil)
            computeCommandEncoder.setBuffer(resultBuffer, offset: 0, atIndex: 2)
            
            var solvedFlag = false;
            var solvedFlagBuffer = device.newBufferWithBytes(&solvedFlag, length: sizeofValue(solvedFlag), options: nil)
            computeCommandEncoder.setBuffer(solvedFlagBuffer, offset: 0, atIndex: 1)
            
            var random = Int(arc4random_uniform(UInt32.max))
            var randomBuffer = device.newBufferWithBytes(&random, length: sizeofValue(random), options: nil)
            computeCommandEncoder.setBuffer(randomBuffer, offset: 0, atIndex: 3)
            
            // make grid
            var threadsPerGroup = MTLSize(width: 512, height: 1, depth: 1)
            var numThreadgroups = MTLSize(width: (Int)(pow(Double(2), Double(0))), height: 1, depth:1)
            println("Block: \(threadsPerGroup.width) x \(threadsPerGroup.height)\nGrid: \(numThreadgroups.width) x \(numThreadgroups.height) x \(numThreadgroups.depth)")
            computeCommandEncoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
            
            // compute and wait for result
            computeCommandEncoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            // Get GPU data
            // outVectorBuffer.contents() returns UnsafeMutablePointer roughly equivalent to char* in C
            var data = NSData(bytesNoCopy: resultBuffer.contents(),
                length: board.count * sizeof(Int32), freeWhenDone: false)
            
            // get data from GPU into Swift array
            data.getBytes(&board, length: board.count * sizeof(Int32))
        }
        else {
            board = sudokuSolver(board);
        }
        
        collectionView.reloadData()
    }
    
    @IBAction func reset(sender: UIButton) {
        board =
            [1, 0, 0, 0, 0, 8, 4, 6, 0,
             2, 8, 0, 0, 4, 6, 9, 0, 0,
             0, 0, 0, 0, 1, 5, 0, 2, 8,
             4, 0, 9, 0, 0, 0, 2, 0, 6,
             3, 0, 0, 0, 2, 0, 0, 0, 5,
             6, 0, 2, 0, 0, 0, 7, 0, 4,
             8, 6, 0, 4, 7, 0, 0, 0, 2,
             0, 0, 1, 8, 5, 0, 0, 4, 9,
             0, 9, 4, 1, 0, 0, 0, 0, 3]
        
        collectionView.reloadData()
    }
    
    // MARK: - Metal
    
    func initMetal() -> (MTLDevice, MTLCommandQueue, MTLLibrary, MTLCommandBuffer, MTLComputeCommandEncoder) {
            // Get access to iPhone or iPad GPU
            var device = MTLCreateSystemDefaultDevice()
            
            // Queue to handle an ordered list of command buffers
            var commandQueue = device.newCommandQueue()
            
            // Access to Metal functions that are stored in Shaders.metal file, e.g. sigmoid()
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

        return permutations
    }
}

