%This script will read in data from CSO observations. For each
%observation, we will then pull the modis data in the corresponding grid
%cell. This will allow us to validate the modis data. Presently, I am
%testing this only on the 2017-2019 water years. This is easily generalized.

clear all
close all
clc

%path to modis files
pth='/Volumes/dfh/data/MOD10a1/files'; %use this if on mac, with attic mounted

%path to cso .csv file. This file has the structure:
%latitude,longitude,altitude,geometry,id,author,depth,source,timestamp,elevation,_ms
csofile='/Volumes/dfh/data/CSO_OBS/cso_2017-2019.csv';

%projection information.See 
%https://modis-land.gsfc.nasa.gov/pdf/MODIS_C6_BA_User_Guide_1.0.pdf

    %define params about modis proj
    R=6371007.181;  %rad of sphere
    T=1111950;  %modis tile size
    xmin=-20015109;
    ymax= 10007555;
    w=463.31271653;

%We are only concerned with certain MODIS tiles. Here are vectors of their
%numbers
h=[7 8 8 9 9 9 10 10 10 11 11 11 12 12 12 13 13];
v=[5 4 5 3 4 5 3 4 5 3 4 5 3 4 5 3 4];
%here are string arrays of them
hstr={'07','08','08','09','09','09','10','10','10','11','11','11', ...
    '12','12','12','13','13'};
vstr={'05','04','05','03','04','05','03','04','05','03','04','05', ...
    '03','04','05','03','04'};

%load the cso observations
dat=readtable(csofile);
lon=dat.longitude;
lat=dat.latitude;
depth=dat.depth; % cm
elev=dat.elevation; % m
timestamp=dat.timestamp;

%pick apart date information from the timestamp vector.
for j=1:length(timestamp)
    y(j)=str2num(timestamp{j}(1:4));
    m(j)=str2num(timestamp{j}(6:7));
    d(j)=str2num(timestamp{j}(9:10));
end

%compute day of year of the observations
doy=day(datetime(y,m,d),'dayofyear');

%Let's first plot the cso data
%compute projected coords of cso observation locations. Need lon / lat in
%radians
lonrad=lon*pi/180; latrad=lat*pi/180;
X=R*lonrad.*cos(latrad);
Y=R*latrad;
figure(1);
scatter(X,Y,'b.')
hold on

%next, let us plot the bounding boxes of the tiles that we have from
%modis...
for p=1:length(h)
    H=h(p); V=v(p);
    I=[0 2399 2399 0 0]; J=[0 0 2399 2399 0];
    xbox=(J+0.5)*w+H*T+xmin;
    ybox=ymax-(I+0.5)*w-V*T;
    plot(xbox,ybox,'k')
end
xlabel('x (m)'); ylabel('y (m)'); title('CSO Observations and MODIS tile boundaries');

%ok, next let us proceed with determing which tiles / rows / columns our
%CSO observations are in.

%get the vectors of tile locations for the observations.
H=floor((X-xmin)/T); V=floor((ymax-Y)/T);
    
%get the row (i) and column (j) coords of the grid cells within the
%appropriate tile. They range from 0 to 2399. Note: for some reason i am
%getting some j = -1 values. So, note the code to adjust to 0 as needed for
%those points...
I=floor(mod((ymax-Y),T) / w - 0.5); I(I<0)=0; I(I>2399)=2399;
J=floor(mod((X-xmin),T) / w - 0.5); J(J<0)=0; J(J>2399)=2399;

%now we are ready to loop over the cso measurements and get the
%corresponding MODIS value for that day / location.

%what follows below is the best (fastest) way that I have found to identify
%the files of interest. The naming convention of MODIS files is odd. And,
%using Matlab dir commands is incredibly slow. So, below I use a bash
%command to create the directory listing. NOTE: make sure target directory
%does NOT have the .xml files in there (duplicate file names).
% 1. dump file listing to a text file. ONLY do this if the file does not
% yet exist. REMEMBER to regen this file anytime you add more MODIS files.
if exist('filelist.txt') ~=2
    eval(['! ls ' pth ' > filelist.txt'])
end

% 2. read this listing in into a string array.
fid=fopen('filelist.txt');
data=textscan(fid,'%s');
fclose(fid)
filelist=string(data{:}); %this is now a list of all of our MODIS files, and we 
% are going to search within ths list.

for j=1:length(lon)
    j
    
    lon_cso=lon(j); lat_cso=lat(j); %coords of jth cso point.
    
    %what file are we looking for? Build up file name
    if doy(j)<10
        tmp=['MOD10A1.A' num2str(y(j)) '00' num2str(doy(j))];
    elseif doy(j)>=10 & doy(j)<100
        tmp=['MOD10A1.A' num2str(y(j)) '0' num2str(doy(j))];
    else
        tmp=['MOD10A1.A' num2str(y(j)) num2str(doy(j))];
    end
    %next add piece having to do with a particular tile.
    index=find(h==H(j) & v==V(j));
    
    %add tile info to filename string
    tmpstr=[tmp '.h' hstr{index} 'v' vstr{index}];
    
    %lets find the right file...
    matches=strfind(filelist,tmpstr); %look for the string in the avail files for our day
    location=find(~cellfun(@isempty,matches)); %find the location of correct tile
    tilefile=filelist(location);
    tilefile_full=strcat(pth, '/', filelist(location));
    
    if ~isempty(location)
        %load file
        finfo=hdfinfo(tilefile_full,'eos');
        sc=hdfread(tilefile_full,'NDSI_Snow_Cover');
        sc=double(sc);
        %extract data at our location
        SC(j)=sc(I(j)+1,J(j)+1);
    else
        SC(j)=NaN;
    end
end

figure(2)
set(gcf,'PaperPosition',[1,1,4,3])
hist(SC,100);
axis([0 100 0 250])
xlabel('NDSI'); ylabel('Count')
title('CSO 2017 - 2019 Observations')







