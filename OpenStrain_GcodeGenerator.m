%% Tension Bioreactor Linear Loading Regime .gcode Generator
% Matthias Eames - 29/10/2024
% Uses absolute coordinates

%% Start up
clear
close all
clc

%% Initialisation Parameters
scaf = 15; % scaffold length in mm
strain = 5; % target strain in %
freq = 0.5; % target cycle frequency in Hz
td = 5/60; % test duration in hours
res = 10; % test step resolution, leave at 1 for linear. Basically how much it subdivides
preload = 1; % Preload, as a percentage of the scaffold length. Once the program starts, this is the lowest value it will go to

home = 0; % Home at start of program? Options: [1 0] (yes no)

%% Linear Loading Regime Program
delta = scaf * (strain/100); % calculates travel distance in mm (=amplitude)
PLdelta = delta - (preload/100)*scaf; % calculates delta with the applied pre-strain
Fspeed = 60*2*PLdelta*freq*1.8; % Calculates F speed to complete the half cycle at the set frequency, adjusted to be better

% Location Grid
testpoints(:,1) = 0:(1/freq/(2*res)):(60*60*td); % Array of test time points (s)
testpoints(:,2) = -PLdelta*0.5* cos((testpoints(:,1))*pi()*2*freq)+0.5*delta+(preload/200)*scaf; % Array of test position points (mm)

for i = 1:height(testpoints)
    if abs(testpoints(i,2)) < (10^-6) % cleaning up where MATLAB doesn't want to equal 0
        testpoints(i,2) = 0;
    end
end
% Figure
figure
plot(testpoints(:,1),testpoints(:,2))
xlim([0 10])
ylim([(-1.5*PLdelta) (1.5*PLdelta)])
title('Test Cycle Waveform Snapshot')
xlabel('Time (s)')
ylabel ('Pull arm location(mm)')

% Make sure it ends at zero strain!!

%% Flipping coordinates because negative is towards motor, and I want that
testpoints(:,2) = -1*testpoints(:,2);

%% Adding adjusting code to start at loading 0 point
testpointsX = testpoints(:,2)+4.4; % X axis 0 is at 4.4mm
testpointsY = testpoints(:,2)+4.2; % Y axis 0 is at 4.2mm (thi is the shadow one)(white black red)
testpointsZ = testpoints(:,2)+4.3; % Y axis 0 is at 4.3mm

%% Writing the GCODE file
% File creation and set up

if home == 1
    filename = ['D',num2str(strain),'%_F',num2str(freq),'Hz_PL',num2str(preload,2),'%_Time',num2str(td,3),'h_XYZ_ABS_G10Program_','Scaflength', num2str(scaf), 'mm.gcode'];
else
    filename = ['NOHOME_D',num2str(strain),'%_F',num2str(freq),'Hz_Time',num2str(td),'h_XYZ_ABS_G10Program_','Scaflength', num2str(scaf), 'mm.gcode'];
end

fileID = fopen(filename, 'w');
code = 'G1 X%1.4f Y%1.4f Z%1.4f E%1.4f \n'; %1.4f means it will do it to 4 decimal places

% Initial comments
fprintf(fileID, '; gcode for controlling the bioreactor with the Gen10 Controller \n');
fprintf(fileID, '; Test duration:%1.4f h \n', td);
fprintf(fileID, '; Strain:%1.2f \n \n', strain);
fprintf(fileID, '; Preload:%1.2f \n \n', preload);
fprintf(fileID, '; Negative X direction compresses the scaffold \n \n');
fprintf(fileID, 'G1 F300 \n'); % Set global speed to 300 so homing is faster

fprintf(fileID, 'M77 ; Pause the print timer \n');
if home == 1
    fprintf(fileID, 'G28 X Y Z; Home the X, Y & Z axes \n \n');
else 
    fprintf(fileID, '; G28 X Y Z; Home the X, Y & Z axes \n \n');
end

fprintf(fileID, 'G90 \n'); % absolute positioning
fprintf(fileID, 'G1 X4.4 Y4.2 Z4.3 \n'); % Start by going to loading positions
fprintf(fileID, 'G1 F%1.3f \n', Fspeed); % Set F for accurate frequency
fprintf(fileID, '; Pause the program until the user clicks \n');
fprintf(fileID, 'M0 Click to continue \n'); % Pause
fprintf(fileID, 'M75 ; start the print timer \n'); % Pause

% %gcode loop
% for timepoint = 1:height(testpointsX)
%     fprintf(fileID, code, testpointsX(timepoint,1), testpointsY(timepoint,1), testpointsZ(timepoint,1), testpointsX(timepoint,1));
% end

tic;
% Perplexity vectorized buffer approach
% Combine all data into a single matrix
data = [testpointsX, testpointsY, testpointsZ, testpointsX];

% Create the formatted string in memory
buffer = sprintf(code, data');

% Write the entire buffer at once
fprintf(fileID, '%s', buffer);

fprintf(fileID, 'M78 ; show print stats \n'); % Pause
% fprintf(fileID, 'M0 Click to continue \n'); % Pause again for kicks
fprintf(fileID, 'G1 F300 \n'); % Set speed back to F300
fprintf(fileID, '; It is the end');

fclose(fileID);

toc;
