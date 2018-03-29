function Kilosort2Neurosuite(rez)
% Converts KiloSort output (.rez structure) to Neurosuite files: fet,res,clu,spk files.
% Based on the GPU enable filter from Kilosort and fractions from Brendon
% Watson's code for saving Neurosuite files.
%
% 1) Waveforms are extracted from the dat file via GPU enabled filters.
% 2) Features are calculated in parfor loops.
%
% Inputs:
%   rez -  rez structure from Kilosort
%
% By Peter Petersen 2018
% petersen.peter@gmail.com

t1 = tic;
spikeTimes = uint64(rez.st3(:,1)); % uint64
spikeTemplates = uint32(rez.st3(:,2)); % uint32 % template id for each spike
kcoords = rez.ops.kcoords;
basename = rez.ops.basename;

Nchan = rez.ops.Nchan;
samples = rez.ops.nt0;

templates = zeros(Nchan, size(rez.W,1), rez.ops.Nfilt, 'single');
for iNN = 1:rez.ops.Nfilt
    templates(:,:,iNN) = squeeze(rez.U(:,iNN,:)) * squeeze(rez.W(:,iNN,:))';
end
amplitude_max_channel = [];
for i = 1:size(templates,3)
    [~,amplitude_max_channel(i)] = max(range(templates(:,:,i)'));
end

template_kcoords = kcoords(amplitude_max_channel);
kcoords2 = unique(template_kcoords);
ia = [];
for i = 1:length(kcoords2)
    kcoords3 = kcoords2(i);
    disp(['-Loading data for spike group ', num2str(kcoords3)])
    template_index = find(template_kcoords == kcoords3);
    ia{i} = find(ismember(spikeTemplates,template_index));
end

rez.ia = ia;
toc(t1)
disp('Saving .clu files to disk (cluster indexes)')
for i = 1:length(kcoords2)
    kcoords3 = kcoords2(i);
    disp(['-Saving .clu file for group ', num2str(kcoords3)])
    tclu = spikeTemplates(ia{i});
    tclu = cat(1,length(unique(tclu)),double(tclu));
    cluname = fullfile([basename '.clu.' num2str(kcoords3)]);
    fid=fopen(cluname,'w');
    fprintf(fid,'%.0f\n',tclu);
    fclose(fid);
    clear fid
end
toc(t1)

disp('Saving .res files to disk (spike times)')
for i = 1:length(kcoords2)
    kcoords3 = kcoords2(i);
    tspktimes = spikeTimes(ia{i});
    disp(['-Saving .res file for group ', num2str(kcoords3)])
    resname = fullfile([basename '.res.' num2str(kcoords3)]);
    fid=fopen(resname,'w');
    fprintf(fid,'%.0f\n',tspktimes);
    fclose(fid);
    clear fid
end
toc(t1)

disp('Extracting waveforms')
waveforms_all = Kilosort_ExtractWaveforms(rez);
toc(t1)

disp('Saving .spk files to disk (waveforms)')
for i = 1:length(kcoords2)
    disp(['-Saving .spk for group ', num2str(kcoords2(i))])
    fid=fopen([basename,'.spk.',num2str(kcoords2(i))],'w');
    fwrite(fid,waveforms_all{i}(:),'int16');
    fclose(fid);
end
toc(t1)

disp('Computing PCAs')
% Starting parpool if stated in the Kilosort settings
if (rez.ops.parfor & isempty(gcp('nocreate'))); parpool; end

for i = 1:length(kcoords2)
    kcoords3 = kcoords2(i);
    disp(['-Computing PCAs for group ', num2str(kcoords3)])
    PCAs_global = zeros(3,sum(kcoords==kcoords3),length(ia{i}));
    waveforms = waveforms_all{i};
    
    waveforms2 = reshape(waveforms,[size(waveforms,1)*size(waveforms,2),size(waveforms,3)]);
    wranges = int64(range(waveforms2,1));
    wpowers = int64(sum(waveforms2.^2,1)/size(waveforms2,1)/100);
    
    % Calculating PCAs in parallel if stated in ops.parfor
    if isempty(gcp('nocreate'))
        for k = 1:size(waveforms,1)
            PCAs_global(:,k,:) = pca(zscore(permute(waveforms(k,:,:),[2,3,1]),[],2),'NumComponents',3)';
        end
    else
        parfor k = 1:size(waveforms,1)
            PCAs_global(:,k,:) = pca(zscore(permute(waveforms(k,:,:),[2,3,1]),[],2),'NumComponents',3)';
        end
    end
    disp(['-Saving .fet files for group ', num2str(kcoords3)])
    PCAs_global2 = reshape(PCAs_global,size(PCAs_global,1)*size(PCAs_global,2),size(PCAs_global,3));
    factor = (2^15)./max(abs(PCAs_global2'));
    PCAs_global2 = int64(PCAs_global2 .* factor');
    
    fid=fopen([basename,'.fet.',num2str(kcoords3)],'w');
    Fet = double([PCAs_global2; wranges; wpowers; spikeTimes(ia{i})']);
    nFeatures = size(Fet, 1);
    formatstring = '%d';
    for ii=2:nFeatures
        formatstring = [formatstring,'\t%d'];
    end
    formatstring = [formatstring,'\n'];
    
    fprintf(fid, '%d\n', nFeatures);
    fprintf(fid,formatstring,Fet);
    fclose(fid);
end
toc(t1)
disp('Complete!')



	function waveforms_all = Kilosort_ExtractWaveforms(rez)
        % Extracts waveforms from a dat file using GPU enable filters.
        % Based on the GPU enable filter from Kilosort.
        % All settings and content are extracted from the rez input structure
        %
        % Inputs:
        %   rez -  rez structure from Kilosort
        %
        % Outputs:
        %   waveforms_all - structure with extracted waveforms
        
        % Extracting content from the .rez file
        ops = rez.ops;
        NT = ops.NT;
        d = dir(ops.fbinary);
        NchanTOT = ops.NchanTOT;
        chanMap = ops.chanMap;
        chanMapConn = chanMap(rez.connected>1e-6);
        kcoords = ops.kcoords;
        ia = rez.ia;
        spikeTimes = rez.st3(:,1);
        
        if ispc
            dmem         = memory;
            memfree      = dmem.MemAvailableAllArrays/8;
            memallocated = min(ops.ForceMaxRAMforDat, dmem.MemAvailableAllArrays) - memfree;
            memallocated = max(0, memallocated);
        else
            memallocated = ops.ForceMaxRAMforDat;
        end
        ops.ForceMaxRAMforDat   = 10000000000;
        memallocated = ops.ForceMaxRAMforDat;
        nint16s      = memallocated/2;
        
        NTbuff      = NT + 4*ops.ntbuff;
        Nbatch      = ceil(d.bytes/2/NchanTOT /(NT-ops.ntbuff));
        Nbatch_buff = floor(4/5 * nint16s/ops.Nchan /(NT-ops.ntbuff)); % factor of 4/5 for storing PCs of spikes
        Nbatch_buff = min(Nbatch_buff, Nbatch);
        
        DATA =zeros(NT, NchanTOT,Nbatch_buff,'int16');
        
        if isfield(ops,'fslow')&&ops.fslow<ops.fs/2
            [b1, a1] = butter(3, [ops.fshigh/ops.fs,ops.fslow/ops.fs]*2, 'bandpass');
        else
            [b1, a1] = butter(3, ops.fshigh/ops.fs*2, 'high');
        end
        
        if isfield(ops,'xml')
            disp('Loading xml from rez for probe layout')
        elseif exist(fullfile(ops.root,[ops.basename,'.xml']))==2
            disp('Loading xml for probe layout from root folder')
%             xml = LoadXml(fullfile(ops.root,[ops.basename,'.xml']));
            xml = LoadParameters(fullfile(ops.root,[ops.basename,'.xml']));
            ops.xml = xml;
        end
        
        fid = fopen(ops.fbinary, 'r');
        
        waveforms_all = [];
        kcoords2 = unique(ops.kcoords);
        
        channel_order = [];
        indicesTokeep = [];
        for i = 1:length(kcoords2)
            kcoords3 = kcoords2(i);
            waveforms_all{i} = zeros(sum(kcoords==kcoords3),ops.nt0,size(rez.ia{i},1));
            if exist('xml')
                channel_order{i} = xml.AnatGrps(i).Channels+1;
                ch_subset = find(kcoords==kcoords3);
                [~,indicesTokeep{i},~] = intersect(channel_order{i},ch_subset);
                [~,indicesTokeep{i}] = sort(indicesTokeep{i});
            end
        end
        
        fprintf('Extraction of waveforms begun \n')
        for ibatch = 1:Nbatch
            if mod(ibatch,10)==0
                if ibatch~=10
                    fprintf(repmat('\b',[1 length([num2str(round(100*(ibatch-10)/Nbatch)), ' percent complete'])]))
                end
                fprintf('%d percent complete', round(100*ibatch/Nbatch));
            end
            
            offset = max(0, 2*NchanTOT*((NT - ops.ntbuff) * (ibatch-1) - 2*ops.ntbuff));
            if ibatch==1
                ioffset = 0;
            else
                ioffset = ops.ntbuff;
            end
            fseek(fid, offset, 'bof');
            buff = fread(fid, [NchanTOT NTbuff], '*int16');
            
            %         keyboard;
            
            if isempty(buff)
                break;
            end
            nsampcurr = size(buff,2);
            if nsampcurr<NTbuff
                buff(:, nsampcurr+1:NTbuff) = repmat(buff(:,nsampcurr), 1, NTbuff-nsampcurr);
            end
            if ops.GPU
                dataRAW = gpuArray(buff);
            else
                dataRAW = buff;
            end
            
            dataRAW = dataRAW';
            dataRAW = single(dataRAW);
            dataRAW = dataRAW(:, chanMapConn);
            dataRAW = dataRAW-median(dataRAW,2);
            datr = filter(b1, a1, dataRAW);
            datr = flipud(datr);
            datr = filter(b1, a1, datr);
            datr = flipud(datr);
            DATA = gather_try(int16( datr(ioffset + (1:NT),:)));
            dat_offset = offset/NchanTOT/2+ioffset;
            % Saves the waveforms occuring within each batch
            for i = 1:length(kcoords2)
                kcoords3 = kcoords2(i);
                ch_subset = find(kcoords==kcoords3);
                temp = find(ismember(spikeTimes(ia{i}), [ops.nt0/2:size(DATA,1)-ops.nt0/2]+ dat_offset));
                temp2 = spikeTimes(ia{i}(temp))-dat_offset;
                for ii = 1:length(temp)
                    waveforms_all{i}(:,:,temp(ii)) = DATA(temp2(ii)-ops.nt0/2+1:temp2(ii)+ops.nt0/2,ch_subset(indicesTokeep{i}))';
                end
            end
        end
        fprintf('\n Extraction of waveforms complete \n')
    end
end
