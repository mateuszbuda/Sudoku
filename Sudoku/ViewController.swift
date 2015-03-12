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
    var board = [Int](count: 81, repeatedValue: 0)

    override func viewDidLoad() {
        super.viewDidLoad()
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
        var cells = collectionView.visibleCells();
        for (var i = 0; i < 81; ++i) {
            board[i] = (cells[i] as CollectionCell).textField.text.toInt()!;
        }
        
        // initialize Metal
        var (device, commandQueue, defaultLibrary, commandBuffer, computeCommandEncoder) = initMetal()
        
        // set up a compute pipeline with sudokuSolver function and add it to encoder
        let sudokuSolver = defaultLibrary.newFunctionWithName("sudokuSolver")
        var pipelineErrors = NSErrorPointer()
        var computePipelineFilter = device.newComputePipelineStateWithFunction(sudokuSolver!, error: pipelineErrors)
        computeCommandEncoder.setComputePipelineState(computePipelineFilter!)
        
        // calculate byte length of input data - board
        var boardByteLength = board.count * sizeofValue(board[0])
        
        // create a MTLBuffer - input data for GPU
        var inVectorBuffer = device.newBufferWithBytes(&board, length: boardByteLength, options: nil)
        
        // set the input vector for the sudokuSolver function, e.g. inVector
        // atIndex: 0 here corresponds to buffer(0) in the sudokuSolver function
        computeCommandEncoder.setBuffer(inVectorBuffer, offset: 0, atIndex: 0)
        
        // create the output vector for the sudokuSolver function, e.g. outVector
        // atIndex: 2 here corresponds to buffer(2) in the sudokuSolver function
        var resultdata = [Int](count:board.count, repeatedValue: 0)
        var outVectorBuffer = device.newBufferWithBytes(&resultdata, length: boardByteLength, options: nil)
        computeCommandEncoder.setBuffer(outVectorBuffer, offset: 0, atIndex: 2)
        
        var solvedFlag = false;
        var solvedFlagBuffer = device.newBufferWithBytes(&solvedFlag, length: 1, options: nil)
        computeCommandEncoder.setBuffer(solvedFlagBuffer, offset: 0, atIndex: 1)
        
        // make grid
        var threadsPerGroup = MTLSize(width: 512, height: 512, depth: 1)
        var numThreadgroups = MTLSize(width: 1024, height:1024, depth:1)
        computeCommandEncoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        
        // compute and wait for result
        computeCommandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Get GPU data
        // outVectorBuffer.contents() returns UnsafeMutablePointer roughly equivalent to char* in C
        var data = NSData(bytesNoCopy: outVectorBuffer.contents(),
            length: board.count * sizeof(Int), freeWhenDone: false)
        
        // get data from GPU into Swift array
        data.getBytes(&board, length: board.count * sizeof(Int))
        
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

