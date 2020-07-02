%This script will simply plot MODIS daily 500m tiles over CONUS (more or
%less). The user can select a day to plot. Presently, the range of data
%available is 9/1/2017 - 8/31/2018 (easily expanded)

clear all
close all
clc

%path to files
pth='/Volumes/dfh/data/MOD10a1/files'; %use this if on mac, with attic mounted

%choose day to plot [Y, M, D]
D=[2017,11,15];

%check to see if in range
if datenum(D(1),D(2),D(3)) < datenum(2017,9,1) | ...
        datenum(D(1),D(2),D(3)) > datenum(2018,8,31)
    error('Please pick a date between 8/31/17 - 9/1/18'); 
end

%compute day of year
d=datetime(D);
doy=day(d,'dayofyear');

%We are plotting only certain MODIS tiles. Here are vectors of their
%numbers
h=[7 8 8 9 9 9 10 10 10 11 11 11 12 12 12 13 13];
v=[5 4 5 3 4 5 3 4 5 3 4 5 3 4 5 3 4];
%here are string arrays of them
hstr={'07','08','08','09','09','09','10','10','10','11','11','11', ...
    '12','12','12','13','13'};
vstr={'05','04','05','03','04','05','03','04','05','03','04','05', ...
    '03','04','05','03','04'};

%define params about modis proj
R=6371007.181;  %rad of sphere
T=1111950;  %modis tile size
xmin=-20015109;
ymax= 10007555;
w=463.31271653;

%what follows below is the best (fastest) way that I have found to identify
%the files of interest. The naming convention of MODIS files is odd. And,
%using Matlab dir commands is incredibly slow. So, below I use a bash
%command to create the directory listing. NOTE: make sure target directory
%does NOT have the .xml files in there (duplicate file names).
% 1. dump file listing to a text file.
eval(['! ls ' pth ' > filelist.txt'])

% 2. read this listing in into a string array.
fid=fopen('filelist.txt');
data=textscan(fid,'%s');
fclose(fid)
filelist=string(data{:});

%loop over the files and plot them, if they exist. We have to begin by building
%up the the partial file name (doy + particular tile) First convert dir
%listing to cell array.
%tmp=struct2cell(dirlist); tmp=tmp'; tmp=tmp(:,1);

%these commands need to be outside the loop
figure(3)
worldmap([25 65],[-145 -60])
set(gcf,'PaperPosition',[1,1,5,4])

for j=1:length(h)
    j
    %what string (horiz / vert tile) are we looking for? First deal with
    %doy piece
    if doy<10
        tmp=['MOD10A1.A' num2str(D(1)) '00' num2str(doy)];
    elseif doy>=10 & doy<100
        tmp=['MOD10A1.A' num2str(D(1)) '0' num2str(doy)];
    else
        tmp=['MOD10A1.A' num2str(D(1)) num2str(doy)];
    end
    %next add piece having to do with a particular tile.
    tmpstr=[tmp '.h' hstr{j} 'v' vstr{j}];
    
    matches=strfind(filelist,tmpstr); %look for the string in the avail files for our day
    location=find(~cellfun(@isempty,matches)); %find the location of correct tile
    tilefile=filelist(location);
    tilefile_full=strcat(pth, '/', filelist(location));
    
    %load file
    finfo=hdfinfo(tilefile_full,'eos');
    sc=hdfread(tilefile_full,'NDSI_Snow_Cover');
    sc=double(sc);
    %remove flagged cells (only keep valid ones)
    sc(sc==200)=NaN; %missing
    sc(sc==201)=NaN; %no decision
    sc(sc==211)=NaN; % night
    sc(sc==250)=NaN; %cloud
    sc(sc==254)=NaN; %detector saturated
    sc(sc==255)=NaN; %fill
    sc(sc==237)=NaN; %inland water
    sc(sc==239)=NaN; %ocean
    
    %creat row-column grids
    [c,r]=meshgrid(0:2399,0:2399);
    
    %get H and V tile coords
    tilefilechar=char(tilefile);
    H=str2num(tilefilechar(19:20)); V=str2num(tilefilechar(22:23));
    %compute x,y values
    x=(c+0.5)*w+H*T+xmin;
    y=ymax-(r+0.5)*w-V*T;
    
    %this makes a plot in projected coords
    %figure(1)
    %pcolor(x,y,sc);shading flat
    %hold on
    
    %convert to geo
    lat=y/R*180/pi;
    lon=x/R./cosd(lat)*180/pi;
    
    %this makes a plot in geo coords
    %figure(2)
    %pcolor(lon,lat,sc);shading flat
    %axis([-145 -55 30 60])
    %hold on
    
    %this makes a nice looking plot in geo coords
    %worldmap
    figure(3)
    geoshow(lat,lon,sc,'DisplayType','surface')
    hold on
end

figure(3)
load coastlines
plotm(coastlat, coastlon,'k')
states = shaperead('usastatelo', 'UseGeoCoords', true);
geoshow(states, 'DisplayType', 'polygon','FaceColor','none')
colorbar
caxis([0 100])
title(['Year / Month / Day = ' num2str(D(1)) '/' num2str(D(2)) ...
    '/' num2str(D(3))])

print -dpng -r300 daily_modis.png



