% A modified version of ICL_feature_extractor.m from the ICLabel EEGLAB
% plugin. We don't compute the topographic map, and concatenate the
% features in a single vector instead of saving them separately in cells.

function features = extract_psd_and_autocorr(EEG, flag_autocorr)
%% check inputs
if ~exist('flag_autocorr', 'var') || isempty(flag_autocorr)
    flag_autocorr = false;
end

% check for ica
assert(isfield(EEG, 'icawinv'), 'You must have an ICA decomposition to use ICLabel')

% assuming chanlocs are correct
if ~isequal(EEG.ref, 'average') && ~isequal(EEG.ref, 'averef')
    [~, EEG] = evalc('pop_reref(EEG, [], ''exclude'', setdiff(1:EEG.nbchan, EEG.icachansind));');
end

% calculate ica activations if missing and cast to double
if isempty(EEG.icaact)
    EEG.icaact = eeg_getica(EEG);
end
EEG.icaact = double(EEG.icaact);

% check ica is real
assert(isreal(EEG.icaact), 'Your ICA decomposition must be real to use ICLabel')

%% calc psd
psd = eeg_rpsd(EEG, 100);

% extrapolate or prune as needed
nfreq = size(psd, 2);
if nfreq < 100
    psd = [psd, repmat(psd(:, end), 1, 100 - nfreq)];
end

% undo notch filter
for linenoise_ind = [50, 60]
    linenoise_around = [linenoise_ind - 1, linenoise_ind + 1];
    difference = bsxfun(@minus, psd(:, linenoise_around), ...
        psd(:, linenoise_ind));
    notch_ind = all(difference > 5, 2);
    if any(notch_ind)
        psd(notch_ind, linenoise_ind) = mean(psd(notch_ind, linenoise_around), 2);
    end
end

% normalize
psd = bsxfun(@rdivide, psd, max(abs(psd), [], 2));

% reshape and cast
% psd = single(permute(psd, [3 2 4 1]));

%% calc autocorrelation?
if flag_autocorr
    if EEG.trials == 1
        if EEG.pnts / EEG.srate > 5
            autocorr = eeg_autocorr_welch(EEG);
        else
            autocorr = eeg_autocorr(EEG);
        end
    else
        autocorr = eeg_autocorr_fftw(EEG);
    end

    % reshape and cast
%     autocorr = single(permute(autocorr, [3 2 4 1]));
end

%% format outputs
if flag_autocorr
    features = [0.99 * psd 0.99 * autocorr];
else
    features = 0.99 * psd;
end
