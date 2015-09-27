function [] = arl ()
    %% LOAD CONFIGURATION %%
    
    % get experiment directory
    base_dir = [ uigetdir([], 'Select experiment directory') '/' ];
    
    % load the tab-delimited configuration file
    config = ReadStructsFromText([base_dir 'config.txt']);
    
    disp(sprintf('You are running %s\n\n',get_config('StudyName')));

    %% SETUP EXPERIMENT AND SET SESSION VARIABLES %%
    
    % tell matlab to shut up, and seed it's random numbers
    warning('off','all');
    random_seed = sum(clock);
    rand('twister',random_seed);

    [ year, month, day, hour, minute, sec ] = datevec(now);
    start_time = [num2str(year) '-' num2str(month) '-' num2str(day) ' ' num2str(hour) ':' num2str(minute) ':' num2str(sec) ];
    
    % get subject code
    experimenter = input('Enter your (experimenter) name: ','s');
    subject_code = input('Enter subject code: ', 's');
    subject_sex = input('Enter subject sex (M/F):  ', 's');
    subject_age = input('Enter subject age (in months; e.g., X.XX): ', 's');
    habituated_rule = input(sprintf('Which rule would you like the baby to be habituated to? (%s): ', get_config('Rules')), 's');
    
    % is this a valid rule?
    config_rules = get_config('Rules');
    config_rules = strrep(config_rules, '"', '');
    rules = explode(config_rules,',');
    
    if (~any(strcmp(rules,habituated_rule)))
        disp(sprintf('\n\nWARNING!!!!\n\nThe rule "%s" is not valid. You must enter EITHER one\nof these rules for habituation: %s\n\n', habituated_rule, get_config('Rules')));
        habituated_rule = input(sprintf('Which rule would you like the baby to be habituated to? (%s): ', get_config('Rules')), 's');
    end
    
    % begin logging now, because we have the subject_code
    create_log_file();
    log_msg(sprintf('Set base dir: %s',base_dir));
    log_msg('Loaded config file');
    log_msg(sprintf('Study name: %s',get_config('StudyName')));
    log_msg(sprintf('Random seed set as %s via "twister"',num2str(random_seed)));
    log_msg(sprintf('Start time: %s',start_time));
    log_msg(sprintf('Experimenter: %s',experimenter));
    log_msg(sprintf('Subject Code: %s',subject_code));
    log_msg(sprintf('Subject Sex: %s',subject_sex));
    log_msg(sprintf('Subject Age: %s',subject_age));
    log_msg(sprintf('Habituated Rule: %s',habituated_rule));
    
    % initiate data structure for session file
    data = struct('key',{},'value',{});

    % set current directory as working directory
    cd(base_dir);

    % wait for experimenter to press Enter to begin
    disp(upper(sprintf('\n\nPress any key to launch the experiment window\n\n')));
    KbWait([], 2);
    
    log_msg('Experimenter has launched the experiment window');

    %% SETUP SCREEN %%

    if (get_config('DebugMode') == 1)
        % skip sync tests for faster load
        Screen('Preference','SkipSyncTests', 1);
        log_msg('Running in DebugMode');
    else
        % shut up
        Screen('Preference', 'SuppressAllWarnings', 1);
        log_msg('Not running in DebugMode');
    end

    % disable the keyboard
    ListenChar(2);

    % create window
    screen_number = max(Screen('Screens'));
    wind = Screen('OpenWindow',screen_number);
    
    log_msg(sprintf('Using screen #%s',num2str(screen_number)));
    
    % initialize sound driver
    log_msg('Initializing sound driver...');
    InitializePsychSound;
    log_msg('Sound driver initialized.');
    
    % we may want PNG images
    Screen('BlendFunction', wind, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    % grab height and width of screen
    res = Screen('Resolution',screen_number);
    sheight = res.height;
    swidth = res.width;
    winRect = Screen('Rect', wind);
    
    log_msg(sprintf('Screen resolution is %s by %s',num2str(swidth),num2str(sheight)));

    % wait to begin experiment
    Screen('TextFont', wind, 'Helvetica');
    Screen('TextSize', wind, 25);
    DrawFormattedText(wind, 'Press any key to begin!', 'center', 'center');
    Screen('Flip', wind);

    KbWait([], 2);
    
    log_msg('Experimenter has begun experiment.');

    %% RUN EXPERIMENT TRIALS %%
    
    % BUILD HABITUATION STIMULI
    % assemble A and B stimuli
    A = {get_config('A_1') get_config('A_2') get_config('A_3') get_config('A_4')};
    B = {get_config('B_1') get_config('B_2') get_config('B_3') get_config('B_4')};
    
    % exhaustively combine A's and B's into 16 combinations
    combinations = {};
    for i = 1:length(A)
        for j = 1:length(B)
            combinations{length(combinations) + 1} = { A{i} B{j} };
        end
    end
    
    sequences = {};
    for i = 1:length(combinations)
        if strcmpi(habituated_rule,'ABB')
            sequences{i} = { combinations{i}{1} combinations{i}{2} combinations{i}{2} };
        elseif strcmpi(habituated_rule,'AAB')
            sequences{i} = { combinations{i}{1} combinations{i}{1} combinations{i}{2} };
        elseif strcmpi(habituated_rule, 'ABA')
            sequences{i} = { combinations{i}{1} combinations{i}{2} combinations{i}{1} };
        end
    end
    
    % HABITUATION TRIALS
    habituation_criterion = 0;
    looking_times = {};
    
    for k = 1:get_config('MaximumHabituationTrials')
        % get attention
        attention_getter();
        
        % start the trial
        % sequences will randomize, and we will continue execution
        % after the infant looks away more than MaxLookaway (ms)
        [looking_time] = hab_trial(sequences, get_config('MaxLookaway'), get_config('AuditoryStimulus'));
        
        % add looking time to the list so we can calculate
        % if they habituated
        looking_times{length(looking_times) + 1} = looking_time;
        
        % record data from fam trial to data and log
        add_data(sprintf('HabTrial%sLT',num2str(k)),num2str(looking_time));
        log_msg(sprintf('HabTrial%sLT: %s',num2str(k),num2str(looking_time)));
        
        % should we end this habituation trial?
        if k <= 3
            % add total looking to habituation criterion
            habituation_criterion = habituation_criterion + looking_time;
            
            if k == 3
                add_data('HabituationCriterion',num2str(habituation_criterion));
                log_msg(sprintf('HabituationCriterion: %s',num2str(habituation_criterion)));
            end
        else
            % after trial 6, look to see if the last 3 trials
            % was 50% of the habituation criterion
            if k >= 6
                if (looking_times{length(looking_times)} + looking_times{length(looking_times) - 1} + looking_times{length(looking_times) - 2}) <= (habituation_criterion*.5)
                    % habituated!
                    add_data('HabituatedInTrial',num2str(k));
                    log_msg(sprintf('HabituatedInTrial: %s',num2str(k)));
                    break
                end
            end
        end     
    end
    
    % BUILD TEST STIMULI
    % assemble A and B stimuli
    C = { get_config('C_1') get_config('C_2') };
    D = { get_config('D_1') get_config('D_2') };
    
    % exhaustively combine C's and D's into 4 combinations
    combinations = {};
    for i = 1:length(C)
        for j = 1:length(D)
            combinations{length(combinations) + 1} = { C{i} D{j} };
        end
    end
    
    % we'll have 2 sets of test sequences, for each of our 2 rules
    test_sequences = {};
    test_sequences{1} = {};
    test_sequences{2} = {};
    
    % what test ruletypes do we have?
    % we don't want the quotes (") coming from the config file
    % or we get rules like "ABB 
    config_rules = get_config('Rules');
    config_rules = strrep(config_rules, '"', '');
    rules = explode(config_rules,',');
    
    for i = 1:length(combinations)
        if strcmpi(rules{1}, 'ABB')
            test_sequences{1}{i} = { combinations{i}{1} combinations{i}{2} combinations{i}{2} };
        elseif strcmpi(rules{1}, 'AAB')
            test_sequences{1}{i} = { combinations{i}{1} combinations{i}{1} combinations{i}{2} };
        elseif strcmpi(rules{1}, 'ABA')
            test_sequences{1}{i} = { combinations{i}{1} combinations{i}{2} combinations{i}{1} };
        end
        
        if strcmpi(rules{2}, 'ABB')
            test_sequences{2}{i} = { combinations{i}{1} combinations{i}{2} combinations{i}{2} };
        elseif strcmpi(rules{2}, 'AAB')
            test_sequences{2}{i} = { combinations{i}{1} combinations{i}{1} combinations{i}{2} };
        elseif strcmpi(rules{2}, 'ABA')
            test_sequences{2}{i} = { combinations{i}{1} combinations{i}{2} combinations{i}{1} };
        end
    end
    
    % TEST TRIALS
    test_blocks = 2;
    
    for k = 1:test_blocks
        % we want 2 trials of each type in each block
        test_block = { 1 1 2 2 };
        test_block = test_block(randperm(length(test_block)));
        
        for m = 1:length(test_block)
            block_rule = test_block{m};
            
            % get attention
            attention_getter();
            
            % start the trial
            % sequences will randomize, and we will continue execution
            % after the infant looks away more than MaxLookaway (ms)
            [looking_time] = hab_trial(test_sequences{block_rule}, get_config('MaxLookaway'), false);
            
            % record data from fam trial to data and log
            add_data(sprintf('Block%sTestTrial%sRule',num2str(k),num2str(m)),rules{block_rule});
            log_msg(sprintf('Block%sTestTrial%sRule: %s',num2str(k),num2str(m),rules{block_rule}));
            add_data(sprintf('Block%sTestTrial%sLT',num2str(k),num2str(m)),num2str(looking_time));
            log_msg(sprintf('Block%sTestTrial%sLT: %s',num2str(k),num2str(m),num2str(looking_time)));
        end
    end
    
    %% POST-EXPERIMENT CLEANUP %%

    post_experiment(false);

    %% HELPER FUNCTIONS %%
    function [value] = get_config (name)
        matching_param = find(cellfun(@(x) strcmpi(x, name), {config.Parameter}));
        value = [config(matching_param).Setting];
    end

    function [key_pressed] = key_pressed ()
        [~,~,keyCode] = KbCheck;
        
        if sum(keyCode) > 0
            key_pressed = true;
        else
            key_pressed = false;
        end
        
        % should we abort
        if strcmpi(KbName(keyCode),'ESCAPE')
            log_msg('Aborting experiment due to ESCAPE key press.');
            post_experiment(true);
        end
    end

    function [total_looking] = hab_trial (sequences, maximum_lookaway, sound_file)
        % randomize the 16 sequences in the set
        sequences = sequences(randperm(length(sequences)));
        
        % start looping and playing sequences
        keypress_start = 0;
        total_looking = 0;
        sequence_start = 0;
        current_sequence = 1;
        last_look = 0;
        soundfile_open = 0;
        sound_file_path = false;
        
        % loop indefinitely
        while (1 ~= 2)
            % look for a keypress
            if key_pressed()
                if (keypress_start == 0)
                    % start a keypress
                    keypress_start = GetSecs();
                end
            else 
                if (keypress_start > 0)
                    total_looking = total_looking + (GetSecs()-keypress_start);
                    last_look = GetSecs();
                    
                    keypress_start = 0;
                end
                
                % have we looked away too long to end the trial?
                if (last_look ~= 0 && (GetSecs() - last_look) >= (maximum_lookaway/1000))
                    break;
                end
            end
            
            % should we play a sound?
            if (soundfile_open == 0)
                if (sound_file ~= false)
                    % do we have an array of sound files? (multiple files
                    % separated by a comma?)
                    if (~isempty(findstr(',', sound_file)))
                        sound_files = explode(sound_file,',');
                        
                        % randomize, and take the first
                        sound_files = sound_files(randperm(length(sound_files)));
                        sound_file_path = sound_files{1};
                    end
                    
                    sound_file_path = [base_dir get_config('StimuliFolder') '/' sound_file_path];
                    
                    log_msg(sprintf('Loading sound from: %s',sound_file_path));
                
                    [wav, freq] = wavread(sound_file_path);
                    wav_data = wav';
                    num_channels = size(wav_data,1);

                    try
                        % Try with the 'freq'uency we wanted:
                        % initialize sound with "reallyneedlowlatency"
                        % == 1
                        InitializePsychSound(1);
                        pahandle = PsychPortAudio('Open', [], [], 0, freq, num_channels);
                    catch
                        % Failed. Retry with default frequency as suggested by device:
                        psychlasterror('reset');
                        pahandle = PsychPortAudio('Open', [], [], 0, [], num_channels);
                    end

                    % Fill the audio playback buffer with the audio data 'wavedata':
                    PsychPortAudio('FillBuffer', pahandle, wav_data);

                    soundfile_open = 1;
                end
            end
            
            if sequence_start == 0
                % white screen between sequences
                Screen('Flip', wind);
                WaitSecs(get_config('TimingBetweenTrials') / 1000);
                
                if (sound_file_path ~= false)
                    % Start audio playback for 'repetitions' repetitions of the sound data,
                    % start it immediately (0) and wait for the playback to start, return onset
                    % timestamp.
                    PsychPortAudio('Start', pahandle, 1, GetSecs() + (get_config('TimingAudioFromTrialOnset')/1000), 1);
                end
                
                % put first image on the screen
                draw_sequence(sequences{current_sequence}{1}, false, false);
                
                sequence_start = GetSecs();
                
                second_shown = 0;
                third_shown = 0;
            elseif (second_shown == 0 && ((GetSecs() - sequence_start) > ((get_config('TimingBetweenElements')/1000) * 1)))
                % draw second image on the screen
                draw_sequence(sequences{current_sequence}{1}, sequences{current_sequence}{2}, false);
                
                second_shown = 1;
            elseif (third_shown == 0 && ((GetSecs() - sequence_start) > ((get_config('TimingBetweenElements')/1000) * 2)))
                % draw third image
                draw_sequence(sequences{current_sequence}{1}, sequences{current_sequence}{2}, sequences{current_sequence}{3});
                
                third_shown = 1;
            elseif (((GetSecs() - sequence_start) > ((get_config('TimingAfterElementsVisible')/1000) + ((get_config('TimingBetweenElements')/1000) * 2))))
                % prepare for new sequence
                sequence_start = 0;
                
                if current_sequence < length(sequences)
                    current_sequence = current_sequence + 1;
                else
                    current_sequence = 1;
                end
                
                % close sound if playing...
                if (sound_file_path ~= false)
                    % Stop sound
                    PsychPortAudio('Stop', pahandle);
                    
                    % if we have more than one sound, then we need to
                    % close/open the port each time
                    if (~isempty(findstr(',', sound_file)))
                        PsychPortAudio('Close', pahandle);
                        soundfile_open = 0;
                    end
                end
            end
        end    
        
        % close sound if playing...
        if (sound_file ~= false)
            % Close the audio device:
            PsychPortAudio('Close', pahandle);
        end
    end

    % draw_sequence
    %
    function draw_sequence (element_1_name, element_2_name, element_3_name)
        % element 1 image
        if (element_1_name ~= false)
            filename = [base_dir 'stimuli/' element_1_name];
            [element_1 map alpha] = imread(filename);
            % PNG support
            if ~isempty(regexp(element_1_name, '.*\.png'))
                % commented out due to error...
                %element_1(:,:,4) = alpha(:,:);
            end
            
            element_1_imtext = Screen('MakeTexture', wind, element_1);
            element_1_texRect = Screen('Rect', element_1_imtext);
            scaled_1_texRect = element_1_texRect' * [get_config('ImageRatio') get_config('ImageRatio') get_config('ImageRatio') get_config('ImageRatio')];
            
            element_1_l = (swidth / 5);
            element_1_t = (sheight / 2) - (scaled_1_texRect(4)/2) + (sheight / 4);
            element_1_r = (swidth / 5) + (scaled_1_texRect(3));
            element_1_b = (sheight / 2) + (scaled_1_texRect(4)/2) + (sheight / 4);
            
            Screen('DrawTexture', wind, element_1_imtext, [0 0 element_1_texRect(3) element_1_texRect(4)], [element_1_l element_1_t element_1_r element_1_b]);
        end
        
        % element 2 image
        if (element_2_name ~= false)
            filename = [base_dir 'stimuli/' element_2_name];
            [element_2 map alpha] = imread(filename);
            % PNG support
            if ~isempty(regexp(element_2_name, '.*\.png'))
                % commented out due to error...
                %element_2(:,:,4) = alpha(:,:);
            end
            
            element_2_imtext = Screen('MakeTexture', wind, element_2);
            element_2_texRect = Screen('Rect', element_2_imtext);
            scaled_2_texRect = element_2_texRect' * [get_config('ImageRatio') get_config('ImageRatio') get_config('ImageRatio') get_config('ImageRatio')];
            
            element_2_l = (swidth / 2) - (scaled_2_texRect(3)/2);
            element_2_t = (sheight / 2) - (scaled_2_texRect(4)/2) + (sheight / 4);
            element_2_r = (swidth / 2) + (scaled_2_texRect(3)/2);
            element_2_b = (sheight / 2) + (scaled_2_texRect(4)/2) + (sheight / 4);
            
            Screen('DrawTexture', wind, element_2_imtext, [0 0 element_2_texRect(3) element_2_texRect(4)], [element_2_l element_2_t element_2_r element_2_b]);
        end
        
        % element 3 image
        if (element_3_name ~= false)
            filename = [base_dir 'stimuli/' element_3_name];
            [element_3 map alpha] = imread(filename);
            % PNG support
            if ~isempty(regexp(element_3_name, '.*\.png'))
                % commented out due to error...
                %element_3(:,:,4) = alpha(:,:);
            end
            
            element_3_imtext = Screen('MakeTexture', wind, element_3);
            element_3_texRect = Screen('Rect', element_3_imtext);
            scaled_3_texRect = element_3_texRect' * [get_config('ImageRatio') get_config('ImageRatio') get_config('ImageRatio') get_config('ImageRatio')];
            
            element_3_l = ((swidth / 5)*4) - (scaled_3_texRect(3));
            element_3_t = (sheight / 2) - (scaled_3_texRect(4)/2) + (sheight / 4);
            element_3_r = ((swidth / 5)*4);
            element_3_b = (sheight / 2) + (scaled_3_texRect(4)/2) + (sheight / 4);
            
            Screen('DrawTexture', wind, element_3_imtext, [0 0 element_3_texRect(3) element_3_texRect(4)], [element_3_l element_3_t element_3_r element_3_b]);
        end
        
        Screen('Flip', wind);
        
        % release textures
        if (element_1_name ~= false)
            Screen('Close', element_1_imtext);
        end
        
        if (element_2_name ~= false)
            Screen('Close', element_2_imtext);
        end
        
        if (element_3_name ~= false)
            Screen('Close', element_3_imtext);
        end
    end

    function attention_getter ()
        log_msg('Showing attention getter.');
        
        keypress_time_to_release = (get_config('StartDelay') / 1000);
        
        movie = Screen('OpenMovie', wind, [base_dir get_config('StimuliFolder') '/' get_config('AttentionGetter')]);
        
        % Start playback engine:
        Screen('PlayMovie', movie, 1);
        
        % set scale to 0 so it will be calculated
        texRect = 0;
        
        keypress_start = 0;
        % loop indefinitely
        while (1 ~= 2)
            % look for a keypress
            if key_pressed()
                if (keypress_start == 0)
                    % start a keypress
                    keypress_start = GetSecs();
                elseif (GetSecs - keypress_start > keypress_time_to_release)
                    % we have pressed the key for as long as we need to
                    % move on
                    Screen('PlayMovie', movie, 0);
                    Screen('CloseMovie', movie);
                    
                    Screen('Flip', wind);
                    
                    break
                end
            else
                % keypress is over so clear it (it's not cumulative)
                keypress_start = 0;
            end
            
            
            tex = Screen('GetMovieImage', wind, movie);
            
            % restart movie?
            if tex < 0
                %Screen('PlayMovie', movie, 0);
                Screen('SetMovieTimeIndex', movie, 0);
                %Screen('PlayMovie', movie, 1);
            else
                % Draw the new texture immediately to screen:
                if (texRect == 0)
                    texRect = Screen('Rect', tex);
                    
                    % calculate scale factors
                    scale_w = winRect(3) / texRect(3);
                    scale_h = winRect(4) / texRect(4);
                    
                    dstRect = CenterRect(ScaleRect(texRect, scale_w, scale_h), Screen('Rect', wind));
                end
                
                Screen('DrawTexture', wind, tex, [], dstRect);

                % Update display:
                Screen('Flip', wind);
                
                % Release texture:
                Screen('Close', tex);
            end
        end
        
        Screen('Flip', wind);
        log_msg('Attention getter ended');
    end

    function test_attention_getter ()
        log_msg('Showing attention getter before test trial.');
        
        % set stage variables
        if (strcmp(pos_left,'Object1') == true)
            left_object_name = get_config('Object1');
            right_object_name = get_config('Object2');
        else
            left_object_name = get_config('Object2');
            right_object_name = get_config('Object1');
        end
        
        left_occluder_name = get_config('OccluderL');
        right_occluder_name = get_config('OccluderR');
        
        keypress_time_to_release = (get_config('StartDelay') / 1000);
        
        % set loop variables
        keypress_start = 0;
        sound_played = false;
        % strobe a dot on the screen every 500ms, and play a sound
        strobe_time = .5; % seconds

        alternate_time = GetSecs + strobe_time;
        state = 1;
        
        % loop indefinitely
        while (1 ~= 2)
            % look for a keypress
            if key_pressed()
                if (keypress_start == 0)
                    % start a keypress
                    keypress_start = GetSecs();
                elseif (GetSecs - keypress_start > keypress_time_to_release)
                    % we have pressed the key for as long as we need to
                    % move on
                    break
                end
            else
                % keypress is over so clear it (it's not cumulative)
                keypress_start = 0;
            end
            
            % deal with strobe/sound
            if (alternate_time < GetSecs)
                if (state == 1)
                    state = 0;
                else
                    state = 1;
                end
                
                alternate_time = GetSecs + strobe_time;
                
                % if state is On, add the dot to the screen
                if (state == 1)
                    % play sound
                    sound_file = [base_dir get_config('StimuliFolder') '/' get_config('AttentionGetterSound')];
                    log_msg(sprintf('Loading sound from: %s',sound_file));

                    [wav, freq] = wavread(sound_file);
                    wav_data = wav';
                    num_channels = size(wav_data,1);

                    try
                        % Try with the 'freq'uency we wanted:
                        pahandle = PsychPortAudio('Open', [], [], 0, freq, num_channels);
                    catch
                        % Failed. Retry with default frequency as suggested by device:
                        psychlasterror('reset');
                        pahandle = PsychPortAudio('Open', [], [], 0, [], num_channels);
                    end

                    % Fill the audio playback buffer with the audio data 'wavedata':
                    PsychPortAudio('FillBuffer', pahandle, wav_data);

                    % Start audio playback for 'repetitions' repetitions of the sound data,
                    % start it immediately (0) and wait for the playback to start, return onset
                    % timestamp.
                    PsychPortAudio('Start', pahandle, 1, 0, 1);
                    
                    % so we can close it...
                    sound_played = true;
                    
                    Screen('FillOval', wind, [139 9 172], [ (swidth/2)-15, (sheight/2)-15+(sheight/4), (swidth/2) + 15, (sheight/2) + 15 + (sheight/4) ]);
                end
                
                % re-draw stage, with or without dot
                draw_stage(left_object_name,...
                           right_object_name,...
                           left_occluder_name,...
                           right_occluder_name,...
                           0,...
                           0,...
                           0,...
                           0);
            end
        end
        
        if (sound_played == true)
            % Stop sound
            PsychPortAudio('Stop', pahandle);

            % Close the audio device:
            PsychPortAudio('Close', pahandle);
        end
        
        log_msg('Attention getter ended - starting test trial.');
    end

    function add_data (data_key, data_value)
        data(length(data) + 1).key = data_key;
        data(length(data)).value = data_value;
        
        % print to screen
        disp(sprintf('\n# %s: %s\n',data_key,data_value));
    end

    function post_experiment (aborted)
        log_msg('Experiment ended');
        
        ListenChar(0);
        Screen('CloseAll');
        Screen('Preference', 'SuppressAllWarnings', 0);
        
        if (aborted == false)
            % get experimenter comments
            comments = inputdlg('Enter your comments about attentiveness, etc.:','Comments',3);
            
            % create empty structure for results
            results = struct('key',{},'value',{});

            [ year, month, day, hour, minute, sec ] = datevec(now);
            end_time = [num2str(year) '-' num2str(month) '-' num2str(day) ' ' num2str(hour) ':' num2str(minute) ':' num2str(sec) ];

            results(length(results) + 1).key = 'Start Time';
            results(length(results)).value = start_time;
            results(length(results) + 1).key = 'End Time';
            results(length(results)).value = end_time;
            results(length(results) + 1).key = 'Status';

            if (aborted == true)
                results(length(results)).value = 'ABORTED!';
            else
                results(length(results)).value = 'Completed';
            end
            results(length(results) + 1).key = 'Experimenter';
            results(length(results)).value = experimenter;
            results(length(results) + 1).key = 'Subject Code';
            results(length(results)).value = subject_code;
            results(length(results) + 1).key = 'Subject Sex';
            results(length(results)).value = subject_sex;
            results(length(results) + 1).key = 'Subject Age';
            results(length(results)).value = subject_age;
            results(length(results) + 1).key = 'Comments';
            results(length(results)).value = comments{1};

            results(length(results) + 1).key = 'Habituated Rule';
            results(length(results)).value = habituated_rule;
            
            % merge in data
            for (i = 1:length(data))
                results(length(results) + 1).key = data(i).key;
                results(length(results)).value = data(i).value;
            end
            
            % save session file
            filename = [base_dir 'sessions/' subject_code '.txt'];
            log_msg(sprintf('Saving results file to %s',filename));
            WriteStructsToText(filename,results)
        else
            disp('Experiment aborted - results file not saved, but there is a log.');
        end
    end

    function create_log_file ()
        fileID = fopen([base_dir 'logs/' subject_code '-' start_time '.txt'],'w');
        fclose(fileID);
    end

    function log_msg (msg)
        fileID = fopen([base_dir 'logs/' subject_code '-' start_time '.txt'],'a');
        
        [ year, month, day, hour, minute, sec ] = datevec(now);
        timestamp = [num2str(year) '-' num2str(month) '-' num2str(day) ' ' num2str(hour) ':' num2str(minute) ':' num2str(sec) ];
        
        fprintf(fileID,'%s - %s\n',timestamp,msg);
        fclose(fileID);
    end

    function [split,numpieces] = explode(string,delimiters)
        %   Created: Sara Silva (sara@itqb.unl.pt) - 2002.04.30

        if isempty(string) % empty string, return empty and 0 pieces
           split{1}='';
           numpieces=0;

        elseif isempty(delimiters) % no delimiters, return whole string in 1 piece
           split{1}=string;
           numpieces=1;

        else % non-empty string and delimiters, the correct case

           remainder=string;
           i=0;

           while ~isempty(remainder)
                [piece,remainder]=strtok(remainder,delimiters);
                i=i+1;
                split{i}=piece;
           end
           numpieces=i;
        end
    end

end