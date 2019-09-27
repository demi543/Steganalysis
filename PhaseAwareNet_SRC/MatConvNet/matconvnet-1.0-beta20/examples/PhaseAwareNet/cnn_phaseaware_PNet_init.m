function net = cnn_phaseaware_PNet_init(varargin)
% Define and initialize PhaseAwareNet net
opts.networkType = 'dagnn' ;
opts.batchSize = 40;
opts.seed = 0;
opts.lrSequence = 'step_long2';
opts = vl_argparse(opts, varargin) ;

rng( opts.seed );

net.layers = {} ;

convOpts = {'CudnnWorkspaceLimit', 1024*1024*1204} ;

HPF = zeros(5, 5, 1, 4, 'single');

HPF(:,:,1,1) = [ -1,  2,  -2,  2, -1; ...
                  2, -6,   8, -6,  2; ...
                 -2,  8, -12,  8, -2; ...
                  2, -6,   8, -6,  2; ...
                 -1,  2,  -2,  2, -1]/12;

HPF(:,:,1,2) = [  0,    0,    5.2,    0,   0; ...
                  0, 23.4,   36.4, 23.4,   0; ...
                5.2, 36.4, -261.0, 36.4, 5.2; ...
                  0, 23.4,   36.4, 23.4,   0; ...
                  0,    0,    5.2,    0,   0]/261;
                   
HPF(:,:,1,3) = [ 0.0562, -0.1354,  0.0000,  0.1354, -0.0562; ...
                 0.0818, -0.1970,  0.0000,  0.1970, -0.0818; ...
                 0.0926, -0.2233,  0.0000,  0.2233, -0.0926; ...
                 0.0818, -0.1970,  0.0000,  0.1970, -0.0818; ...
                 0.0562, -0.1354,  0.0000,  0.1354, -0.0562 ];

HPF(:,:,1,4) = [-0.0562, -0.0818, -0.0926, -0.0818, -0.0562; ...
                 0.1354,  0.1970,  0.2233,  0.1970,  0.1354; ...
                 0.0000,  0.0000,  0.0000, -0.0000, -0.0000; ...
                -0.1354, -0.1970, -0.2233, -0.1970, -0.1354; ...
                 0.0562,  0.0818,  0.0926,  0.0818,  0.0562 ];


net.layers{end+1} = struct('type', 'conv', ...
                           'name', 'HPFs', ...
                           'weights', {{HPF, []}}, ...
                           'learningRate', [0, 0], ...
                           'stride', 1, ...
                           'pad', 2, ...
                           'weightDecay', [0, 0], ...
                           'opts', {convOpts}) ;

% Group 1
net.layers{end+1} = struct('type', 'conv', ...
                           'name', 'CONV_1', ...
                           'weights', {{init_weight('gaussian', 5, 5, 4, 8, 'single'), ... 
                                        []}}, ...
                           'learningRate', [1, 0], ...
                           'stride', 1, ...
                           'pad', 2, ...
                           'weightDecay', [0, 0], ...
                           'opts', {convOpts}) ;
net.layers{end+1} = struct('type', 'abs', 'name', 'ABS_1') ;
net.layers{end+1} = struct('type', 'bnorm', 'name', 'BN_1', ...
                           'weights', {{ones(8, 1, 'single'), ...
                                        zeros(8, 1, 'single'), ...
                                        zeros(8, 2, 'single')}}, ...
                           'learningRate', [1 1 0.01], ...
                           'weightDecay', [0 0]) ;
net.layers{end+1} = struct('type', 'tanh', 'name', 'TanH_1') ;

                           
% Group 2
net.layers{end+1} = struct('type', 'conv', ...
                           'name', 'CONV_2', ...
                           'weights', {{init_weight('gaussian', 5, 5, 8, 16, 'single'), ... 
                                        []}}, ...
                           'learningRate', [1, 0], ...
                           'stride', 1, ...
                           'pad', 2, ...
                           'weightDecay', [0, 0], ...
                           'opts', {convOpts}) ;
net.layers{end+1} = struct('type', 'bnorm', 'name', 'BN_2', ...
                           'weights', {{ones(16, 1, 'single'), ...
                                        zeros(16, 1, 'single'), ...
                                        zeros(16, 2, 'single')}}, ...
                           'learningRate', [1 1 0.01], ...
                           'weightDecay', [0 0]) ;
net.layers{end+1} = struct('type', 'tanh', 'name', 'TanH_2') ;


% Phase split here
net.layers{end+1} = struct('type', 'phasesplit', ...
                           'name', 'DCTPhaseSplit', ...
                           'pool', [1, 1], ...
                           'stride', 8, ...
                           'pad', 0 );

DCTMode = 64;
% Group 3
net.layers{end+1} = struct('type', 'conv', ...
                           'name', 'CONV_3', ...
                           'weights', {{init_weight('gaussian', 1, 1, 16, 32*DCTMode, 'single'), ... 
                                        []}}, ...
                           'learningRate', [1, 0], ...
                           'stride', 1, ...
                           'pad', 0, ...
                           'weightDecay', [0, 0], ...
                           'opts', {convOpts}) ;
net.layers{end+1} = struct('type', 'bnorm', 'name', 'BN_3', ...
                           'weights', {{ones(32*DCTMode, 1, 'single'), ...
                                        zeros(32*DCTMode, 1, 'single'), ...
                                        zeros(32*DCTMode, 2, 'single')}}, ...
                           'learningRate', [1 1 0.01], ...
                           'weightDecay', [0 0]) ;
net.layers{end+1} = struct('type', 'relu', 'name', 'ReLU_3') ;
net.layers{end+1} = struct('type', 'pool', ...
                           'name', 'Pool_3', ...
                           'method', 'avg', ...
                           'pool', [5 5], ...
                           'stride', 2, ...
                           'pad', 2) ;
                         
% Group 4
net.layers{end+1} = struct('type', 'conv', ...
                           'name', 'CONV_4', ...
                           'weights', {{init_weight('gaussian', 1, 1, 32, 64*DCTMode, 'single'), ... 
                                        []}}, ...
                           'learningRate', [1, 0], ...
                           'stride', 1, ...
                           'pad', 0, ...
                           'weightDecay', [0, 0], ...
                           'opts', {convOpts}) ;
net.layers{end+1} = struct('type', 'bnorm', 'name', 'BN_4', ...
                           'weights', {{ones(64*DCTMode, 1, 'single'), ...
                                        zeros(64*DCTMode, 1, 'single'), ...
                                        zeros(64*DCTMode, 2, 'single')}}, ...
                           'learningRate', [1 1 0.01], ...
                           'weightDecay', [0 0]) ;
net.layers{end+1} = struct('type', 'relu', 'name', 'ReLU_4') ;
net.layers{end+1} = struct('type', 'pool', ...
                           'name', 'Pool_4', ...
                           'method', 'avg', ...
                           'pool', [5 5], ...
                           'stride', 2, ...
                           'pad', 2) ;
                         
% Group 5
net.layers{end+1} = struct('type', 'conv', ...
                           'name', 'CONV_5', ...
                           'weights', {{init_weight('gaussian', 1, 1, 64, 128*DCTMode, 'single'), ... 
                                        []}}, ...
                           'learningRate', [1, 0], ...
                           'stride', 1, ...
                           'pad', 0, ...
                           'weightDecay', [0, 0], ...
                           'opts', {convOpts}) ;
net.layers{end+1} = struct('type', 'bnorm', 'name', 'BN_5', ...
                           'weights', {{ones(128*DCTMode, 1, 'single'), ...
                                        zeros(128*DCTMode, 1, 'single'), ...
                                        zeros(128*DCTMode, 2, 'single')}}, ...
                           'learningRate', [1 1 0.01], ...
                           'weightDecay', [0 0]) ;
net.layers{end+1} = struct('type', 'relu', 'name', 'ReLU_5') ;
net.layers{end+1} = struct('type', 'pool', ...
                           'name', 'Pool_5', ...
                           'method', 'avg', ...
                           'pool', [16 16], ...
                           'stride', 1, ...
                           'pad', 0) ;

% Full connect layer
net.layers{end+1} = struct('type', 'conv', ...
                           'name', 'FC',...
                           'weights', {{init_weight('xavier', 1,1,128*DCTMode,2, 'single'), ...
                                        0.01*ones(2, 1, 'single')}}, ...
                           'learningRate', [1 2], ...
                           'weightDecay', [1 0], ...
                           'stride', 1, ...
                           'pad', 0) ;

% Softmax layer
net.layers{end+1} = struct('type', 'softmaxloss', 'name', 'loss') ;

% Meta parameters
net.meta.inputSize = [512 512 1] ;

lr = get_lr_sequence(opts.lrSequence);
net.meta.trainOpts.learningRate = lr;
net.meta.trainOpts.numEpochs = numel(lr) ;
net.meta.trainOpts.batchSize = opts.batchSize ;
net.meta.trainOpts.weightDecay = 0.01; 
                                        

% Fill in default values
net = vl_simplenn_tidy(net) ;

% Switch to DagNN if requested
switch lower(opts.networkType)
  case 'simplenn'
    % done
  case 'dagnn'
    net = dagnn.DagNN.fromSimpleNN(net, 'canonicalNames', true) ;
    net.addLayer('error', dagnn.Loss('loss', 'classerror'), ...
                 {'prediction','label'}, 'error') ;
  otherwise
    assert(false) ;
end                          

% -------------------------------------------------------------------------
function weights = init_weight(weightInitMethod, h, w, in, out, type)
% -------------------------------------------------------------------------
% See K. He, X. Zhang, S. Ren, and J. Sun. Delving deep into
% rectifiers: Surpassing human-level performance on imagenet
% classification. CoRR, (arXiv:1502.01852v1), 2015.
switch lower(weightInitMethod)
  case 'gaussian'
    sc = 0.01 ;
    weights = randn(h, w, in, out, type)*sc;
  case 'xavier'
    sc = sqrt(3/(h*w*in)) ;
    weights = (rand(h, w, in, out, type)*2 - 1)*sc ;
 case 'xavierimproved'
    sc = sqrt(2/(h*w*out)) ;
    weights = randn(h, w, in, out, type)*sc ;    
  otherwise
    error('Unknown weight initialization method''%s''', weightInitMethod);
end

function lr = get_lr_sequence( lrGenerationMethod )

switch lower(lrGenerationMethod)
  case 'step_short'    
    lr = 0.001 * ones(1, 2);
    for i = 1:39
       lr =[lr, lr(end-1:end)*0.9];
    end
  case 'log_short'
    %lr = logspace(-3, -5, 80);
    lr = logspace(-3, -5, 40 );
  case 'step_long'
    numInterationPerEpoch = 8000/64;
    lrStepSize = 5000/numInterationPerEpoch; % 
    totalStep = 220000/5000;  % CNN is trained for 120,000 iterations
    lr = 0.001*ones(1,lrStepSize);
    for i = 1:totalStep - 1
      lr = [lr, lr(end-lrStepSize+1:end) *0.9];
    end
  case 'step_long2'
    numInterationPerEpoch = 8000/64;
    lrStepSize = 2500/numInterationPerEpoch; % 
    totalStep = 12;
    lr = 0.001*ones(1,lrStepSize);
    for i = 1:totalStep - 1
      lr = [lr, lr(end-lrStepSize+1:end) *0.75];
    end  
  case 'step_long3'
    numInterationPerEpoch = 8000/64;
    lrStepSize = 2500/numInterationPerEpoch/2; % 
    totalStep = 10;
    lr = 0.001*ones(1,lrStepSize);
    for i = 1:totalStep - 1
      lr = [lr, lr(end-lrStepSize+1:end) *0.5];
    end    
  otherwise
    error('unkown type of lr sequence generation method''%s''', lrGenerationMethod);
end
