function [sniff_dat, poke_dat] = load_nidaq(mouse_id, session)
    
    % 100-0 condition
    path = "S:/fmon_data/" + num2str(mouse_id) + "/100-0/" + num2str(session) + "/";
    
    %% Load Nidaq Sniff
    nidaq_sniff = path + "NiDAQ_sniff.dat";
    sniff = fopen(nidaq_sniff, 'r'); 
    sniff_dat = fread(sniff, 'double');
    fclose(sniff);
    
    %% Load Nidaq Sniff
    nidaq_poke = path + "NiDAQ_poke.dat";
    poke = fopen(nidaq_poke, 'r'); 
    poke_dat = fread(poke, 'double');
    fclose(poke);

    %% Sniff
    nchannels = 4;
    sniff_dat = reshape(sniff_dat,[nchannels, length(sniff_dat)/nchannels]); % Reshape binary vector to N channel matrix
    poke_dat = reshape(poke_dat,[nchannels-1, length(poke_dat)/(nchannels-1)]); % Reshape binary vector to N channel matrix
end