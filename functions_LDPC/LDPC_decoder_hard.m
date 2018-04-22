function [ bitStream ] = LDPC_decoder_hard( bitStream_enc, H ,while_it_limit )
%LDPC_DECODER_HARD Decode LDPC encoding.
%   Decode LDPC encoding using a hard decoding scheme. This method should
%   go fast and be pretty optimized.
[c_num,v_num]       = size(H);



% %%%
% zerosToPad = c_num - mod(length(bitStream_enc),c_num);
% if (zerosToPad ~= 0)
% %     disp('We need to pad some zeros')
%     bitStream_enc = [bitStream_enc; zeros(zerosToPad,1)];
%     while mod(numel(bitStream_enc),bps) ~= 0                % Infinite loops should not happen, but be careful!
%         bitStream_enc = [bitStream_enc; zeros(c_num,1)];
%         zerosToPad = zerosToPad + c_num;
%     end
% end
% %%%


bitstrm_enc_rshp    = reshape(bitStream_enc,v_num,[])';
H                   = reshape(H',1,v_num,[]);                               % Why do you make dimensions 1x256x128?

v_nodes             = bitstrm_enc_rshp;
v_nodes_old         = inf(size(v_nodes));
while_it            = 0;

if ~exist('while_it_limit','var')
        while_it_limit      = 10;
end

while (while_it ~= while_it_limit) && any(any(mod(v_nodes * permute(H,[2,3,1]),2)))
    while_it        = while_it + 1;
    c_nodes         = mod(sum(v_nodes & H,2),2);
    c_nodes         = reshape(c_nodes,[],1,c_num);
    
    c_xor_v         = xor( v_nodes , c_nodes );
    c_xor_v_masked  = c_xor_v & H;
    average         = ( sum(c_xor_v_masked,3) + bitstrm_enc_rshp ) ./ ( sum(H,3) + 1 );
    average_mask    = average==0.5;
    v_nodes_old     = v_nodes;
    v_nodes         = and(round(average),~average_mask) + and(bitstrm_enc_rshp,average_mask);
end
bitStream           = reshape(v_nodes(:,end-c_num+1:end)',1,[])';
end

