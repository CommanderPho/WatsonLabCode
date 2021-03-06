function [epochs,PETH] = NormTransitionPETHToPrePost(epochs,PETH,numpre,numpost)

1;
if ~isempty(epochs)
%     onzero = find(PETH.t_align_on==0);
%     offzero = find(PETH.t_align_off==0);
%     normzero = find(PETH.t_norm == 0);
%     normone = find(PETH.t_norm == 1);

    normperiod = 'firstpre';%what part of the pre/post to use for normalization
    switch normperiod
        case 'allpre'
            for a = 1:length(epochs)
                n{a} = epochs{a}(1:numpre);
            end
        case 'allpost'
            for a = 1:length(epochs)
                n{a} = epochs{a}(end-numpost+1:end);
            end
        case 'firstpre'%only applies to norm for now
            for a = 1:length(epochs)
                n{a} = epochs{a}(1);
            end
        case 'firstpost'%only applies to norm for now
            for a = 1:length(epochs)
                n{a} = epochs{a}(end-numpost+1);
            end
        case 'center'%only applies to norm for now
            for a = 1:length(epochs)
                n{a} = epochs{a}(numpre+1);
            end
        case 'all'%only applies to norm for now
            for a = 1:length(epochs)
                n{a} = epochs{a}
            end
    end

    normmode = 'meandiv';
    switch normmode
        case 'meandiv'
            for a = 1:length(epochs);
                epochs{a} = epochs{a}/nanmean(n{a});
            end
        case 'meansub'
            for a = 1:length(epochs);
                epochs{a} = epochs{a} - nanmean(n{a});
            end
        case 'median'
            for a = 1:length(epochs);
                epochs{a} = epochs{a}/nanmedian(n{a});
            end
        case 'zscore'%note this will give infs with single point samples (var = 0)
            for a = 1:length(epochs);
                m = nanmean(n{a});
                s = nanstd(n{a});
                epochs{a} = (epochs{a}-m)/s;
            end
        case 'bwnormalize'%set to range of 0 -1
            for a = 1:length(epochs);
                m = nanmin(n{a});
                epochs{a} = epochs{a}-m;
                m = nanmax(n{a});
                epochs{a} = epochs{a}/m;
            end
    end
end

for a = 1:length(epochs);
    n(a,:) = epochs{a};
end
PETH.mean = mean(n,1);
PETH.std = std(n,1);