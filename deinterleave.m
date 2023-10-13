function [A, B] = deinterleave(I)
   A = I(:,:,1:2:end);
   B = I(:,:,2:2:end);