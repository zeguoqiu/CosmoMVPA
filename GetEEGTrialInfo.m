%% Get Trial Information for DotProbe MVPA
xlsxrange=1;
outputfile='DotProbeMVPA_new.xlsx';
for p=1:26
    EEG=ALLEEG(p);
    SID=str2double(regexp(EEG.setname,'\d+(\.)?(\d+)?','match'))
    index=[];
    tmpStruct=[];
    bin=[EEG.event.bini]';
    OGtrialNo=[EEG.event.bepoch]';
    epochNo=[EEG.event.epoch]';
    for r=1:EEG.trials
        tmpIndex=find([EEG.event.epoch]'==r,1,'first');
        index(r,1)=tmpIndex(1,1);
    end
    tmpBin=bin(index,:);
    tmpOGtrialNo=OGtrialNo(index,:);
    tmpEpochNo=epochNo(index,:);
    PID=zeros(EEG.trials,1)+SID;
    tmpStruct=[PID,tmpEpochNo,tmpOGtrialNo,tmpBin];
    writematrix(tmpStruct, outputfile,"WriteMode","append");
end

% get epoch no. for accepted epochs
for n=1:26
    epochNo=([]);
    epochNo(1,1)=str2double(regexp(ALLEEG(n).setname,'\d+(\.)?(\d+)?','match'));
    for i=1:ALLEEG(n).trials
        OGepochNo=ALLEEG(n).epoch(i).eventbepoch{1, 1};
        epochNo(1,i+1)=OGepochNo;
    end
    writematrix(epochNo, 'acceptedEpochs.xlsx',"WriteMode","append");
end
