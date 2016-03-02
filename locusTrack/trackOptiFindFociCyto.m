function [clist, clist_def] = trackOptiFindFociCyto(dirname,CONST,header)

% trackOptiFindFociCyto : Finds foci in cells. Note that this only
% runs if the number of foci to be fit is set in CONST.trackLoci.numSpots.
%
% This is done by :
% (1) Fits autofluor/cytoplasmic fluor background in cells, cell-by-cell
% (2) Makes a mega region of all cells and fits foci in all cell
%     simultaneously as opposed fitting foci cell-by-cell.
%
% INPUT :
%   dirname_xy: is the seg directory in the xy directory
%   skip: frames mod skip are processed
%   CONST: are the segmentation constants.
%   header : string displayed with information
% OUTPUT :
%       clist :
%       clist_def :
%
% Copyright (C) 2016 Wiggins Lab
% University of Washington, 2016
% This file is part of SuperSeggerOpti.

if ~exist('header')
    header = [];
end

dirname = fixDir( dirname );

% Get the track file names
contents=dir([dirname,'*_err.mat']);
num_im = numel(contents);
data_c = loaderInternal([dirname,contents(1).name]);

nc = 0;
tmp_fn = fieldnames( data_c );
nf = numel( tmp_fn );

for j = 1:nf;
    if numel(strfind(tmp_fn{j},'fluor')==1) && ~numel((strfind(tmp_fn{j},'fluor0')))
        nc = nc+1;
    end
end

if ~isfield( data_c, 'fluor1' ) || ~isfield( CONST.trackLoci, 'numSpots' ) ||...
        ~any(CONST.trackLoci.numSpots)
    disp ('No foci were fit. Set the constants if you want foci.');
    return;
end


if CONST.show_status
    h = waitbar( 0, 'Find Loci.');
else
    h = [];
end

parfor i = 1:num_im; % Parallelizing find loci
    intDoFoci( i, dirname, contents, nc, CONST);
    if CONST.show_status
        waitbar(i/num_im,h,['Find Loci--Frame: ',num2str(i),'/',num2str(num_im)]);
    else
        disp( [header, 'FindLoci: No status bar. Frame ',num2str(i), ...
            ' of ', num2str(num_im),'.']);
    end
end

if CONST.show_status
    close(h);
end


end

function data = loaderInternal( filename )
data = load( filename );
end

function intDoFoci( i, dirname, contents, nc, CONST)
% intDoLoci : finds the foci in the image

data_c = loaderInternal([dirname,contents(i).name]);
gf  = fspecial( 'gaussian', 21, 3 );

% make filtered images to fit
im_filt = cell([1,nc]);
for j = 1:nc
    fl_im = getfield( data_c, ['fluor',num2str(j)]);
    fl_im = medfilt2( double(fl_im), [3,3], 'symmetric' );
    Istd(j)  = std(fl_im(data_c.mask_bg));
    tmp = (fl_im-imfilter( fl_im, gf, 'replicate' ))/Istd(j);
    tmp(tmp<0) = 0;
    im_filt{j} = tmp;
end


% Loop through the different fluorescence channels
for channel_number = 1:nc
    if isfield( CONST.trackLoci, 'numSpots' ) && numel(CONST.trackLoci.numSpots)>=channel_number
        if CONST.trackLoci.numSpots(channel_number)
            % only runs if there are non zero number of foci set in constants
            % Fits the foci
            data_c = intFindFociPAWCurve( data_c, CONST, channel_number );
        end
    end
end

dataname = [dirname,contents(i).name];
save(dataname,'-STRUCT','data_c');

end

