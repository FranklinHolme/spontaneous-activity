function [tif_stack] = readTifStack(file_name)

    % Copied from:
    % http://www.matlabtips.com/how-to-load-tiff-stacks-fast-really-fast/

    InfoImage=imfinfo(file_name);
    mImage=InfoImage(1).Width;
    nImage=InfoImage(1).Height;
    samplesPerPixel=InfoImage(1).SamplesPerPixel;
    NumberImages=length(InfoImage);
    if samplesPerPixel > 1
        tif_stack = zeros(nImage,mImage,samplesPerPixel, NumberImages,'uint8');
    else
        tif_stack = zeros(nImage,mImage, NumberImages,'uint16');
    end 

    TifLink = Tiff(file_name, 'r');
    for i=1:NumberImages
       TifLink.setDirectory(i);
       if samplesPerPixel > 1
            tif_stack(:,:,:,i) = TifLink.read();
       else
           tif_stack(:,:,i) = TifLink.read();
       end
    end
    TifLink.close();
end