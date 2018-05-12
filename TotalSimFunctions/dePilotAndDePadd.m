function [dataOut] = dePilotAndDePadd(dataIn,paddLength,pilot,K,T,varargin)
%DEPILOTANDDEPADD Depilot and depadd
%   Depilot, depadd, frame and frequency aquisistion
dataIn = dataIn(:);
pilot = pilot(:);
T = T(:);

dataLen = numel(dataIn);
N   = numel(pilot);
K_vec   = (1:K)';
Dk  = zeros(numel(K_vec),dataLen);
for ki = 1:numel(K_vec)
    k        = K_vec(ki);
    n        = k+1:dataLen-N;
    l        = (k+1:N)';
    Dk(ki,n) = 1/(N-k).*sum((conj(dataIn(n+l-1)).*repmat(pilot(l),1,size(n,2))).*conj(conj(dataIn(n+l-1-k)).*repmat(pilot(l-k),1,size(n,2))),1);
end
Dk_absMean = mean(abs(Dk),1);
Dk_absMean = Dk_absMean-mean(Dk_absMean);

[~,n_est] = findpeaks([0,Dk_absMean],'MinPeakHeight',0.3,'MinPeakProminence',0.2);
n_est = n_est-1;

delta_f = -1/K .* sum( angle(Dk(K_vec,n_est)) ./ (2*pi*K_vec*T(n_est)'));
delta_f = interp1(n_est,delta_f,1:numel(dataIn),'linear',0)';
dataOut = dataIn .* exp( -1i*2*pi* delta_f );

angle_pilots = mean(angle(dataIn(n_est+(0:numel(pilot)-1)')) - angle(pilot));
angle_data   = interp1(n_est,angle_pilots,1:numel(dataIn),'linear',0)';
dataOut      = dataIn .* exp(-1i*angle_data);


dataOut(n_est'+(0:numel(pilot)-1)) = [];    % Delete pilots
dataOut(end-paddLength+1:end) = [];         % Delete padding

if nargin>5
    plotvar = char(varargin{1});
else
    plotvar = 'noPlot';
end

switch plotvar
    case 'plot'
        figure
        hold on
        plot(Dk_absMean)
        tmp = zeros(size(Dk_absMean));
        tmp(n_est) = Dk_absMean(n_est);
        stem(tmp)
        ylabel('Dk-mean(Dk)');
        title('Dk and estimated loc of pilots')
        hold off
end
end

