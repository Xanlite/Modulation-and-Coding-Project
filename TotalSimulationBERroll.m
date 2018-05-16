clear
close all
clc
addpath(genpath(pwd))
%% INITIALIZATION %%
modu = 'QPSK';
[modulation,bps]    = ModuToModulation(modu);
ftaps               = 800;               % Amount of causal (and non causal) filter taps
symRate             = 2*1e6;            % 2 * cutoffFrequency = 1/T (We use the -3dB point as cutoffFrequency)
T                   = 1/symRate;        % Symbol period
M                   = 100;               % UpSample factor
fs                  = symRate * M;      % Sample Frequency
beta                = 0.3;              % Roll off factor
beta2                = 0.7;              % Roll off factor
N                   = 128*12;            % Amount of bits in original stream
hardDecodeIter      = 10;               % Iteration limit for hard decoder
cLength             = 128;
vLength             = 256;
SNRdB               = 200;              % Signal to noise in dB
fc                  = 2e9;              % 2 GHz carrier freq is given as example in the slides
ppm                 = 2e-6;             % 2 parts per million
% deltaW              = fc*ppm;           % Carrier frequency offset CFO 10ppm 10e-6
deltaW              = 0;
phi0                = 0;                % Phase offset
delta               = 0;                % Sample clock offset SCO
t0                  = (-0.5:0.02:0.5)*T;                % Time shift
K_gard              = 0.01;             % K for Gardner
K_gard2              = 0.05;             % K for Gardner

% SNRdB               = -10:0.1:10;
nrOfIterations = 5;                % To take mean and std
BER             = zeros(size(SNRdB));
BER_no_gardner  = zeros(size(SNRdB));
for i=1:length(SNRdB)
    for tt=1:length(t0)
        disp(['t0 is ',num2str(t0(tt))])
        for ii=1:nrOfIterations
            %% Create bitstream
            [stream_bit]        = CreateBitStream(N,1);

            stream_coded = stream_bit; %!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            %% Mapping
            stream_mapped       = mapping(stream_coded, bps, modulation);

            %% Upsample
            stream_upSampled    = upsample(stream_mapped,M); %%!!!!!!!!!!!!!!

            %% Create window
            [g,g_min]           = CreateWindow(T, fs, ftaps, beta);
            [g2,g_min2]           = CreateWindow(T, fs, ftaps, beta2);

            %% Apply window
            stream_wind         = conv(stream_upSampled,g);
            stream_wind2         = conv(stream_upSampled,g2);

            %% Sending through channel
            stream_channel = stream_wind; %%%%!!!!!%%%%
            stream_channel2 = stream_wind2; %%%%!!!!!%%%%

            %% CFO + Phase offset
            stream_rec_CFOPhase = AddCFOAndPhase(stream_channel,fs,deltaW,phi0);
            stream_rec_CFOPhase2 = AddCFOAndPhase(stream_channel2,fs,deltaW,phi0);

            %% Apply window
            stream_rec_wind     = conv(stream_rec_CFOPhase,g_min);
            stream_rec_wind2     = conv(stream_rec_CFOPhase2,g_min2);

            %% Truncate & Sample + Sample clock offset and time shift
            stream_rec_sample   = TruncateAndSample(stream_rec_wind,ftaps,T,fs,delta,t0(tt)); %@Mathias, ik geef gwn T mee ipv T/2 om te kunnen vergelijken
            stream_rec_sample2   = TruncateAndSample(stream_rec_wind2,ftaps,T,fs,delta,t0(tt));

            %% Gardner
    %         epsilon = zeros(nrOfIterations,numel(stream_rec_sample));        % DON'T DO THIS, THIS GIVES STRANGE RESULTS BECAUSE OF MEAN AND STD
            disp(['Gardner iteration: ',num2str(ii)])
            [~, ~, epsilon(ii,:)]  = Gardner(stream_rec_sample, K_gard, stream_rec_wind, ftaps, fs, T,delta, t0(tt));
            [~, ~, epsilon2(ii,:)]  = Gardner(stream_rec_sample2, K_gard, stream_rec_wind2, ftaps, fs, T,delta, t0(tt));

        end
    epsilonLast = epsilon(:,end); %we're only interested in the last value
    epsilonLast2 = epsilon2(:,end);
    meanEps(tt) = mean(epsilonLast);
    meanEps2(tt) = mean(epsilonLast2);
    end
    
    figure
    plot(t0./T,meanEps,'-*')
    hold on
    plot(t0./T,meanEps2,'-o')
    xlabel('Normalized time error')
    ylabel('Feedback loop correction term (mean only)')
    title('QPSK, 2 Mbps symbol rate, varying roll off, no noise')
    legend('Roll off 0.3','Roll off 0.7')
    grid on
    
    
    
    
    
    error = (t0/T-abs(epsilon))*T;
    error2 = (t0/T-abs(epsilon2))*T;
    
    avg = mean(error,1);
    stddev = std(error,1);
    avg2 = mean(error2,1);
    stddev2 = std(error2,1);
    
    avgFilt = 1/20*ones(20,1);
    avg     = conv(avg,avgFilt,'same');
    stddev  = conv(stddev,avgFilt,'same');
    avg2     = conv(avg2,avgFilt,'same');
    stddev2  = conv(stddev2,avgFilt,'same');
    
    avg     = avg(10:end);
    stddev  = stddev(10:end);   
    avg2     = avg2(10:end);
    stddev2  = stddev2(10:end);  
    
    
    
    steps = 1:20:numel(avg);
    figure
    plot(steps,avg(steps),'-or')
    hold on
    plot(steps,avg2(steps),'-xb')
    
    plot(steps,avg(steps)-stddev(steps),'--or')
    plot(steps,avg(steps)+stddev(steps),'--or')
    plot(steps,avg2(steps)-stddev2(steps),'--xb')
    plot(steps,avg2(steps)+stddev2(steps),'--xb')
    
    title('QPSK, 2 Mbps symbol rate, 0.3 roll-off, no noise')
    xlabel('Symbols')
    ylabel('Time error (mean \pm stdv)')
    ylim(1e-7*[-0.5,3])
    legend(['K = ',num2str(K_gard)],['K = ',num2str(K_gard2)])
    hold off

end

rmpath(genpath(pwd))