% detEdit.m

% This script operates on output from mkTTPP.m and mkLTSAsessions.m. It
% allows the user to visually review detections, in order to manually
% flag false positives, and/or classify detections according to type.
% 
% Script is based on original version by JA Hildebrand (8-12-2014) and 
% Updates by KE Frasier 05-19-2015

% Inputs:
% 1) Settings are read in from detEdit_settings.m

% 2) From TTPP file
% NOTE - this file is generated by mkTTPP.m
% MTT: An Nx2 vector of detection start and end times, where N is the
% number of detections
% MPP: An Nx1 vector of recieved level (RL) amplitudes.
% MSP: An NxF vector of detection spectra, where F is dictated by the
% parameters of the fft used to generate the spectra and any normalization 
% preferences.
% f = An Fx1 frequency vector associated with MSP

% 3) From LTSA (Long Term Spectral Average) file.
% NOTE - this file is generated by mkLTSAsessions.m
% pwr: LTSA session power vector. A cell array where each cell pwr{k} 
% contains the LTSA for a given bout k.
% pt: LTSA session time vector. A cell array where each cell pt{k} 
% contains the times associated with the LTSA for a given bout k.
% nb: the total number of bouts k
% sb: A kx1 vector of bout start times as matlab dnums
% eb: A kx1 vector of bout end times as matlab dnums
% bd: A kx1 vector of bout durations in seconds
% df: Frequency bin width associated with LTSA in Hz. Often 100Hz.
% gt: Maximum gap time allowed between bouts in seconds.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clearvars
warning('off')

% Get input settings by reading setup script
detEdit_Settings

dnum2sec = 24*60*60;
% Adjust some parameters based on initial inputs

% Round color codes so they'll be matchable
colortab = round(colortab*100)/100;

% Building and checking input/output files
% Check to confirm that detection file exists
if exist(fn,'file') ~= 2
    disp(['Error: File Does Not Exist: ',fn])
    return
end
load(fn)

% Check for false detection (FD) if it doesn't exist, create it.
[inPath,inTTPP,inExt] = fileparts(fn);
inFD = strrep(inTTPP,'TTPP','FD');
fnFD = fullfile(inPath,[inFD,inExt]);
if exist(fnFD,'file')~=2;
    disp(['Create New FD file: ',fnFD])
    zFD = [];
    save(fnFD,'zFD');
end

% Check for identified detection (ID) if it doesn't exist, create it.
inID = strrep(inTTPP,'TTPP','ID');
fnID = fullfile(inPath,[inID,inExt]);
if exist(fnID,'file')~=2;
    disp(['Create New FD file: ',fnID])
    zID = [];
    save(fnID,'zID');
end

% Load FD and ID files
load(fnFD)
load(fnID)

% Check to see if there are detections that are labeled both as false
% positives, and as IDs, and remove any diplicates from the false positive
% list
if ~isempty(zFD)
    zFD = setdiff(zFD(:,1),zID(:,1));
    save(fnFD,'zFD');
end

% LTSA session file: check for it
inLTSA = strrep(inTTPP,'TTPP','LTSA');
fnLTSA = fullfile(inPath,[inLTSA,inExt]);
if exist(fnLTSA,'file')~=2;
    disp(['Error: LTSA Sessions File Does Not Exist: ',fn5])
    return
else
    % load it if it exists
    disp('Loading LTSA Sessions, please wait ...')
    load(fnLTSA)
    disp('Done Loading LTSA Sessions')
end
% Compute freq axis for LTSA
fimin = fimin * 10;     % 5khz
fimax = fimax * 10;    % 100khz
ltsaF = (fimin*df):df:(fimax*df); % LTSA freq vec

[~, specMinIdx] = min(f-normFreq(1));
[~, specMaxIdx] = max(f-normFreq(2));
fTrunc = f(specMinIdx:specMaxIdx)/1000;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
pause on
% Display some info about magic keys
disp('Press ''u'' key to update display')
disp('Press ''s'' key to update with new IPI scale')
disp('Press ''b'' key to go backward')
disp('Press any other key to go forward')
cc = ' ';  % avoids crash when first bout too short

% Ask the user which bout they want to start with.
% Default is 1 (first bout)
k = input('Starting Session:  ');
if isempty(k)
    k = 1;
end

%%%%%%%%%%%%%%%%%%%%%%%%% Begin Main Loop %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% loop over the number of bouts
while (k <= nb)

    % Load in FD and MD each session in case they have been modified during
    % a previous iteration.
    load(fnFD)  % brings in zFD
    load(fnID)  % brings in zID
    
    % find detections and false detections within this bout
    J = find(MTT(:,1) >= sb(k) & MTT(:,1) <= eb(k));
    
    if ~isempty(J)
        nd = length(J);    % number of detections in this session
        disp([' detection times in this is session:',num2str(nd)])
        
        t = MTT(J,1);      % detection times in this session
        y = MPP(J);        % received levels in this session
        specJ = MSP(J,:);  % spectra in this session
        
        % Figure out which of these detection times have been flagged as
        % false positives
        [~,commonSetFD,~] = intersect(t,zFD);
        nFD = size(commonSetFD,1);
        % set this flag to true if the number of detections in this bout is
        % equal to the number of false detections
        if nFD >= nd
            allFalse = 1;
        else
            allFalse = 0;
        end
        
        tfd = [];
        if allFalse && falseFlag
            % if all of the detections are false, and the falseFlag is
            % true, skip the bout
            disp(' All false detections in this is session - skipping')
            if ~strcmp(cc,'b') && ~strcmp(cc,'u') && ~strcmp(cc,'a')
                k = k + 1;
                continue
            end
        elseif nFD == 0
            % if there are no false detections
            ff2 = 0;
            disp(' No False Det')
        else
            disp([' False detections in this is session:',num2str(nFD)])
            ff2 = 1;
            tfd = t(commonSetFD);
            yfd = y(commonSetFD);
        end
        
        % Figure out which of these detection times have been classified
        [~,ctIdx,zIDidx] = intersect(t,zID(:,1),'rows');
        imd = cell(size(colortab,1),1);
        if length(ctIdx)>1
            ff3 = 1;
            disp([' ID in this is session:',num2str(length(ctIdx))])
            tmd = t(ctIdx); %time
            ymd = y(ctIdx); %received level
            smd = zID(zIDidx,2); % species id
            specmd = specJ(ctIdx,:); % spectra for that species
            for i = 1 : size(colortab,1)
                imd{i} = find(smd == i); %create cell array
            end
        else
            ff3 = 0;
            disp(' No ID')
        end
    else
        disp('Error: no detections between bout start and end')
        return
    end
        % and convert from days to seconds
    dtfd=[];
    dt = diff(t)*dnum2sec; %compute IDI

    if ff2
        dtfd = dt(commonSetFD(1:end-1));
    end
    if ff3
        dtmd = dt(ctIdx(1:end-1));
        dtmd = [dtmd ; dtmd(end)]; % copy last point to make same size as tmd
    end
    
    disp(['Session: ',num2str(k),'  Start: ',datestr(sb(k)),'  End:',datestr(eb(k))])
    
    % Convert inter-detection interval (IDI) from days to seconds
    len = length(dt);
    tdt2 = zeros(2*len,1);
    dt2 = zeros(2*len,1);
    for idt = 1 : len
        idt2 = 2*idt;
        tdt2(idt2-1:idt2) = [t(idt); t(idt+1)];
        dt2(idt2-1:idt2) = [dt(idt);dt(idt)];
    end
        
    PT = pt{k};   % LTSA session time vector
    pwr1 = pwr{k};  % LTSA power vector
    if isempty(pwr1)
        disp('Empty LTSA')
        continue;
    end
    
    % Begin plotting
    figure(200);clf
    subplot(2,1,1)
    hold on
    
    % figure out which clicks have NOT been identified as ID or FD
    [~,noNameSet] = setdiff(J, [J(commonSetFD);J(cell2mat(imd))]);    
    if ~isempty(noNameSet)
        specUnkSet = specJ(noNameSet,:);
        specNormUnk = norm_spec(specUnkSet,[specMinIdx,specMaxIdx]);
   
        if ~isempty(fTrunc)
            h2 = plot(fTrunc,specNormUnk,'-b','LineWidth',3);
        else
            h2 = plot(specNormUnk,'-b','LineWidth',3);
        end
        hold on
    end
    
    if ff3 % if there are ID'd detections
        for i0 = 1 : size(colortab,1) % for each type
            if (~isempty(imd{i0}))
                % normalize the clicks and plot the mean spectra
                specIDSet = specmd(imd{i0},:);
                specIDNorm = norm_spec(specIDSet,[specMinIdx,specMaxIdx]);

                if length(specIDNorm)>1
                    plot(fTrunc,specIDNorm,'-', ...
                        'Color',colortab(i0,:),'LineWidth',3);
                    xlabel('Frequency (kHz)')
                    ylabel('Normalized Amplitude')
                    tString = {['Start Time ',datestr(sb(k))]};
                    title(tString);
                end
            end
        end
    end
    ylim([0,1])
    grid on
    hold off
    
    subplot(2,1,2)
    dtNofd = setdiff(dt2,dtfd);
    dtNofd_trim = (dtNofd <= dl & dtNofd > .01);
    dttVec = 0:.01:dl;
    hDtt = histc(dtNofd(dtNofd_trim),dttVec);
    bar(dttVec,hDtt)
    xlabel('ici')
    xlim([0,dl])
    grid on
    
 
    figure(201);clf;
    % Figure middle panel: RL vs Time 
    hds(1) = subplot(3,1,1); 
    plot(t,y,'.')
    hold on
    if ff2 > 0
        plot(tfd,yfd,'r.')
    end
    if ff3  > 0
        for i = 1 : size(colortab,1)
            if (~isempty(imd{i})) % use specid for color
                plot(tmd(imd{i}),ymd(imd{i}),'.',   ...
                    'MarkerFaceColor',colortab(i,:), ...
                    'MarkerEdgeColor',colortab(i,:));
            end
        end
    end
    hold off
    axis([PT(1) PT(end) RLLims])
    datetick('x',15,'keeplimits')
    grid on
    tstr(1) = {fn};
    tstr(2) = {['Start Time ',datestr(sb(k)),' Detect = ',num2str(nd)]};
    title(tstr);
    ylabel('RL [dB re 1\muPa]')
    
    % Figure middle panel: LTSA 
    hds(2) = subplot(3,1,2);  
    % make frequency vector
    c = (contrast/100) .* pwr1 + bright;
    image(PT,ltsaF,c)
    axis xy
    v2 = axis;
    axis([PT(1) PT(end) v2(3) v2(4)])
    datetick('keeplimits')
    ylabel('Frequency (kHz)')
    hc = colorbar;
    hcy = ylabel(hc,'Amplitude');% no transfer function added for now.
    set(hcy,'rotation',-90,'Position',get(hcy,'Position')+[1 0 0])
    % Figure middle panel: Inter-Detection Interval 
    hds(3) = subplot(3,1,3);  
    plot(tdt2,dt2,'.')
    if ff2 > 0
        hold on
        plot(tfd(2:end),dtfd,'.r')
        hold off
    end
    if ff3 > 0
        hold on
        for i = 1 : size(colortab,1)
            if (~isempty(imd{i})) % use specid for color
                plot(tmd(imd{i}),dtmd(imd{i}),'.',   ...
                    'MarkerFaceColor',colortab(i,:), ...
                    'MarkerEdgeColor',colortab(i,:));
            end
        end
        hold off
    end
    
    pos = get(hds,'Position');
    pos{1}(4) = .25;pos{2}(4) = .3;pos{3}(4) = .25;
    pos{1}(2) = 1-.05-pos{1}(4);
    pos{2}(2) = pos{1}(2)-.025-pos{2}(4);
    pos{2}(3) = pos{1}(3);   
    pos{3}(2) = pos{2}(2)-.025-pos{3}(4);
    hcPos = get(hc,'Position');
    hcPos(1) = (ceil(100*(pos{2}(1)+pos{2}(3))))/100;
    hcPos(3) = 0.02;
    set(hds(1),'Position',pos{1},'XTickLabel',[])
    set(hds(2),'Position',pos{2},'XTickLabel',[])
    set(hds(3),'Position',pos{3})
    set(hc,'Position',hcPos)
    axis([PT(1) PT(end) 0 dl])
    datetick('x',15,'keeplimits')
    ylabel('Time between detections [s]')
    xlabel('Time [GMT]')
    % title('Inter-Detection Interval (IDI)')
    grid on
    
    % end of plotting
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % brush
    Bc = [];
    pause
    % get brushed data JAH 2-22-14
    hBrushLine = findall(gca,'tag','Brushing');
    brushData = get(hBrushLine, {'Xdata'});
    bsize = size(brushData);
    brushIdx = [];
    specid = 0;
    if ~isempty(brushData)
        brushColorOrig = get(hBrushLine, {'Color'});
        brushColor = round(brushColorOrig{1}.*100)/100;
        brushIdx = ~isnan(brushData{1,1});  % get data
        
        %Check for Brush color data
        if max(brushIdx) > 0
            % Put brush capture into Bc matrix
            Bc(:,1) = brushData{1,1}(brushIdx);
            % find the brush color
            colorMatch = zeros(size(colortab,1),1);
            for cItr = 1:size(colortab,1)
                colorMatch(cItr,1)= sum(colortab(cItr,:)==brushColor);
            end
            cMatch = find(colorMatch==3);
            if ~isempty(cMatch)
                specid = cMatch; % Pink = GG1 = id 1
                % write to ID file
                disp(['Number of ID Detections = ',num2str(length(Bc))])
                
                BcCat = [Bc, specid.*ones(length(Bc),1)];
                if ~isempty(zID)
                    [~,iz] = setdiff(zID(:,1),BcCat(:,1));
                    zID = zID(iz,:);
                    zID = [zID; BcCat];  % cummulative Mis-ID Detection matrix
                else
                    zID = BcCat;
                end
                BcCat = [];
                save(fnID,'zID')
            else
                if sum(falseColor==brushColor)==3
                    % False Detections
                    disp(['Number of False Detections = ',num2str(length(Bc))])
                    zFD = [zFD; Bc];   % cummulative False Detection matrix
                    save(fnFD,'zFD')
                elseif sum(resetColor==brushColor)==3
                    % Remove these detections from FD and ID
                    disp(['Number of Detections Selected = ',num2str(length(Bc))])
                    
                    if ~isempty(zID)
                        [~,iC2] = setdiff(zID(:,1),Bc(:,1));
                        disp(['Remaining Number of ID Detections = ',...
                            num2str(length(iC2)-1)])
                        zID = zID(iC2,:);
                        save(fnID,'zID')
                        
                        if ~isempty(zFD)
                            zFD2 = setdiff(zFD(:,1),zID(:,1),'rows');
                            [~,iC] = setdiff(zFD2(:,1),Bc(:,1));
                            disp(['Remaining Number of False Detections = ',...
                                num2str(length(iC)-1)])
                            zFD = zFD2(iC,:);
                            save(fnFD,'zFD')
                        end
                    end
                end
            end
        end
    end
    
    hBrushLine = [];
    brushData = [];
    brushColor = [];
    % don't end if you used paintbrush on last record
    if (k == nb && ~isempty(Bc))
        k = k-1;
        disp(' Last Record')
    end
    clear Bc;
   
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % get key stroke
    cc = get(201,'CurrentCharacter');
    if strcmp(cc,'u')
        disp(' Update Display') % Stay on same bout
    elseif strcmp(cc,'s')
        dl = input(' Update IPI scale (sec):  '); % Set IPI scale
    elseif strcmp(cc,'b') % Move back one bout
        if k ~= 1
            k = k-1;
        end
    elseif strcmp(cc,'a')
        zFD = [zFD; tfd];
        save(fn2,'zFD');
    else
        k = k+1;  % move forward one bout
    end
end
pause off
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%make zFD unique
load(fn2);   % load false detections
[uzFD,ia,ic] = unique(zFD);     % make zFD have unique entries
if (length(ia) ~= length(ic))
    disp([' False Detect NOT UNIQUE - removed:   ', ...
        num2str(length(ic) - length(ia))]);
end
zFD = uzFD;
save(fn2,'zFD');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp(' ')
disp(['Number of Starting Detections = ',num2str(length(ct)+2)])
disp(' ')
disp(['Number of True Detections = ',num2str(length(ct)-length(zFD)-length(zID)+2)])
disp(' ')
disp(['Number of False Detections = ',num2str(length(zFD)-1)])
disp(' ')
disp(['Number of Mis-ID Detections = ',num2str(length(zID(:,1))-1)])
disp(' ')
disp(['Done with file ',fn])
