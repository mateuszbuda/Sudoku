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

class ViewController: UIViewController, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    @IBOutlet weak var collectionView: UICollectionView!
    var board = [Int32](count: 81, repeatedValue: 0)

    override func viewDidLoad() {
        super.viewDidLoad()
        board[0] = 1;
        board[5] = 8;
        board[6] = 4;
        board[7] = 6;
        board[9] = 2;
        board[10] = 8;
        board[13] = 4;
        board[14] = 6;
        board[15] = 9;
        board[22] = 1;
        board[23] = 5;
        board[25] = 2;
        board[26] = 8;
        board[27] = 4;
        board[29] = 9;
        board[33] = 2;
        board[35] = 6;
        board[36] = 3;
        board[40] = 2;
        board[44] = 5;
        board[45] = 6;
        board[47] = 2;
        board[51] = 7;
        board[53] = 4;
        board[54] = 8;
        board[55] = 6;
        board[57] = 4;
        board[58] = 7;
        board[62] = 2;
        board[65] = 1;
        board[66] = 8;
        board[67] = 5;
        board[70] = 4;
        board[71] = 9;
        board[73] = 9;
        board[74] = 4;
        board[75] = 1;
        board[80] = 3;
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
}

