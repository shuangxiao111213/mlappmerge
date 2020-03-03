classdef ExplorerA < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        SimulinkRealTimeExplorerUIFigure  matlab.ui.Figure
        Panel                    matlab.ui.container.Panel
        TargetPanel              matlab.ui.container.Panel
        ConnectDisconnectButton  matlab.ui.control.Button
        LoadApplicationButton    matlab.ui.control.Button
        StartStopButton          matlab.ui.control.Button
        StopTimeField            matlab.ui.control.EditField
        TargetsDropDown          matlab.ui.control.DropDown
        ApplicationTree          matlab.ui.container.Tree
    end

    
    properties (Constant, Access = private)
        connectedIcon      = fullfile(matlabroot, 'toolbox', 'slrt', 'slrt', '+SimulinkRealTime', '+internal', '+guis', 'connected_16.png');
        disconnectedIcon   = fullfile(matlabroot, 'toolbox', 'slrt', 'slrt', '+SimulinkRealTime', '+internal', '+guis', 'disconnected_16.png');
        loadIcon           = fullfile(matlabroot, 'toolbox', 'slrt', 'slrt', '+SimulinkRealTime', '+internal', '+guis', 'load_16.png');
        runIcon            = fullfile(matlabroot, 'toolbox', 'slrt', 'slrt', '+SimulinkRealTime', '+internal', '+guis', 'run_24.png');
        stopIcon           = fullfile(matlabroot, 'toolbox', 'slrt', 'slrt', '+SimulinkRealTime', '+internal', '+guis', 'stop_24.png');
        currentSystemIcon  = fullfile(matlabroot, 'toolbox', 'slrt', 'slrt', '+SimulinkRealTime', '+internal', '+guis', 'currentsystem_16.png');
        curSysAndBelowIcon = fullfile(matlabroot, 'toolbox', 'slrt', 'slrt', '+SimulinkRealTime', '+internal', '+guis', 'currentsystembelow_16.png');
        subsystemIcon      = fullfile(matlabroot, 'toolbox', 'slrt', 'slrt', '+SimulinkRealTime', '+internal', '+guis', 'subsystem_16.png');
        modelrefIcon       = fullfile(matlabroot, 'toolbox', 'slrt', 'slrt', '+SimulinkRealTime', '+internal', '+guis', 'modelref_16.png');
        modelIcon          = fullfile(matlabroot, 'toolbox', 'slrt', 'slrt', '+SimulinkRealTime', '+internal', '+guis', 'model_16.png');
        addIcon            = fullfile(matlabroot, 'toolbox', 'slrt', 'slrt', '+SimulinkRealTime', '+internal', '+guis', 'add_16.png');
        deleteIcon         = fullfile(matlabroot, 'toolbox', 'slrt', 'slrt', '+SimulinkRealTime', '+internal', '+guis', 'delete_16.png');
        logSignalIcon      = fullfile(matlabroot, 'toolbox', 'slrt', 'slrt', '+SimulinkRealTime', '+internal', '+guis', 'log_signal_24.png');
        openSDIIcon        = fullfile(matlabroot, 'toolbox', 'slrt', 'slrt', '+SimulinkRealTime', '+internal', '+guis', 'sdi_visualize_16.png');
        hiliteInModelIcon  = fullfile(matlabroot, 'toolbox', 'slrt', 'slrt', '+SimulinkRealTime', '+internal', '+guis', 'highlight_model_24.png');
        addRowIcon         = fullfile(matlabroot, 'toolbox', 'slrt', 'slrt', '+SimulinkRealTime', '+internal', '+guis', 'add_row_16.gif');
        removeRowIcon      = fullfile(matlabroot, 'toolbox', 'slrt', 'slrt', '+SimulinkRealTime', '+internal', '+guis', 'remove_row_16.png');
        helpIcon           = fullfile(matlabroot, 'toolbox', 'slrt', 'slrt', '+SimulinkRealTime', '+internal', '+guis', 'help_48.png');
    end
    
    properties (Constant, Access = private)
        addToSignalGroupButtonTooltip      = 'Add selected signals to signal group';
        removeFromSignalGroupButtonTooltip = 'Remove selected signals from signal group';
        targetsDropDownTooltip             = 'Manage target computers';
        loadApplicationButtonTooltip       = 'Select new application to load on target computer';
        stopTimeFieldTooltip               = 'Stop time parameter for model';
        helpButtonTooltip                  = 'Help using SLRT Explorer';
        startTooltip                       = 'Start model running on target computer';
        stopTooltip                        = 'Stop model running on target computer';
        disconnectedTooltip                = 'Disconnect from selected target';
        connectedTooltip                   = 'Connect to selected target';
        filterSignalsTooltip               = 'Search signal list in current model';
        filterParametersTooltip            = 'Search parameters in current model';
        contentsOnlyTooltip                = 'Show contents of current system only';
        contentsBelowTooltip               = 'Show contents of current system and below';
        streamSignalGroupTooltip           = 'Stream the current signal group to SDI.  A signal group must be streamed before it is available in the scopes below.';
        highlightSignalButtonTooltip       = {'Highlight the selected signal (indicated by the blue box) in the model.';'Only available if model is open.'};
        highlightParameterButtonTooltip    = {'Highlight the selected parameter (indicated by the blue box) in the model.';'Only available if model is open.'};
        
    end
    
    properties (Access = private)
        targetMap
        signalsGroupMap
        addTargetListener
        removeTargetListener
        renameTargetOldName
        
        progressDlg
        
        scopeIdx = 1
        scopePos
        
        selectedSignalRow
        selectedParameterRow
        
        signalTimer
    end
    
    methods (Static)
        %
        % General utility methods.
        %
        
        function blockPath = convertBlockPathsToDisplayString(blockPaths)
            %
            % blockPaths may be one of the following:
            %
            %   1) Cell array of strings, one for each level of model hierarchy
            %   2) Simulink.SimulationData.BlockPath object
            %
            % The returned value is a single string representing the block.
            %
            % For example:
            %
            % {'top/subsys/myblock'} => 'top/subsys/myblock'
            %
            % {'top/modelblock', 'mid/modelblock', 'sub/foo'} => 'top/modelblock/modelblock/foo'
            %
            if isempty(blockPaths)
                blockPath = blockPaths;
                return;
            end
            
            if isa(blockPaths, 'Simulink.SimulationData.BlockPath')
                blockPaths = blockPaths.convertToCell();
            end
            
            assert(iscell(blockPaths));
            
            if length(blockPaths) == 1
                blockPath = blockPaths{1};
                return;
            end
            
            blockPath = blockPaths{1};                       % Top model path
            for nBlockPath=2:length(blockPaths)              % Recurse over sub models
                idxs = strfind(blockPaths{nBlockPath}, '/'); % Strip sub model name
                assert(~isempty(idxs));
                blockPath = strcat(blockPath, blockPaths{nBlockPath}(idxs(1):end));
            end
        end
        
        
        
        
    end
    
    methods (Static)
        %
        % Methods for accessing SLRT target object.
        %
        
        
        function connected = isSLRTTargetConnected(targetName)
            %
            % Return true if host computer is connected to targetName,
            % false otherwise.
            %
            connected = false;
            tg = SimulinkRealTime.internal.guis.Explorer.getSLRTTargetObject(targetName);
            if ~isempty(tg)
                connected = strcmp(tg.connected, 'Yes');
            end
        end
   
    end
    
    
    methods (Access = private)
        
        function updateGUIForTargetApplicationParameters(app, targetName)
            %
            % Adjust GUI widgets for displaying target application parameters.
            %
            
            % Only adjust widgets if target is currently selected.
            %
            if strcmp(app.getSelectedTargetName(), targetName)
                
                target = app.getTarget(targetName);
                
                selectedApplicationNode = app.ApplicationTree.SelectedNodes;
                if isempty(selectedApplicationNode)
                    app.ParametersTable.UserData = [];
                    app.ParametersTable.Data = [];
                    app.ParametersTable.Enable = 'off';
                    app.HighlightParameterInModelButton.Enable = 'off';
                    app.HighlightParameterInModelButton.Tooltip = '';
                else
                    
                    % Get list of all parameters to display in GUI based on current
                    % selection in application tree.
                    %
                    [blkParamBlkPaths, blkParamParamNames, wksParamBlkPaths, wksParamParamNames] = app.getFlatParameterListsFromNode(selectedApplicationNode, target.filters.currentSystemAndBelow);
                    
                    % Apply filter to list of block/workspace parameters in GUI.
                    %
                    blkpaths   = [wksParamBlkPaths'   blkParamBlkPaths']';
                    paramnames = [wksParamParamNames' blkParamParamNames']';
                    
                    if ~isempty(blkpaths)
                        if ~isempty(target.filters.filterContents)
                            paramNameIdxs = find(cellfun(@(x)contains(x, target.filters.filterContents, 'IgnoreCase', true), paramnames));
                            blkPathIdxs   = find(cellfun(@(x)contains(x, target.filters.filterContents, 'IgnoreCase', true), blkpaths));
                            idxs = union(paramNameIdxs, blkPathIdxs);
                            blkpaths  = blkpaths(idxs);
                            paramnames  = paramnames(idxs);
                        end
                    end
                    
                    % Get initial parameter values for GUI.
                    %
                    [vals, types, dims] = app.getSLRTTargetParameterValues(targetName, target.application.codeDescFolder, blkpaths, paramnames);
                    
                    % Configure GUI with filtered parameters list.
                    %
                    app.ParametersTable.Data = [num2cell(false(size(blkpaths))) blkpaths paramnames vals types dims];
                    app.ParametersTable.Enable = 'on';
                    
                    % Disable buttons because no parameters are selected.
                    %
                    app.HighlightSignalInModelButton.Enable = 'off';
                    app.HighlightSignalInModelButton.Tooltip = '';
                end
            end
        end
        
        function disableGUIForTargetApplication(app)
            %
            % Clear the application tree
            % Set all application widgets to default values
            % Disable all application widgets (except application tree)
            %
            
            if ~isempty(app.ApplicationTree.Children)
                app.ApplicationTree.Children(1).Parent = [];
            end
            app.ApplicationTree.Enable = 'off';
            
            app.FilterCurrentSystemAndBelowButton.Enable = 'off';
            app.FilterCurrentSystemAndBelowButton.Value = false;
            app.FilterCurrentSystemAndBelowButton.Icon = app.currentSystemIcon;
            app.FilterContentsOfLabel.Enable = 'off';
            app.FilterSystemLabel.Enable = 'off';
            app.FilterSystemLabel.Text = '';
            app.FilterContentsEditField.Enable = 'off';
            app.FilterContentsEditField.Value = '';
            
            app.SignalsTable.UserData = [];
            app.SignalsTable.Data = [];
            app.SignalsGroupDropDown.Enable = 'off';
            app.SignalsGroupDropDown.Value = '<no selection>';
            app.SignalsTable.Enable = 'off';
            app.SignalsGroupTable.UserData = [];
            app.SignalsGroupTable.Data = [];
            app.SignalsGroupTable.Enable = 'off';
            app.AddToSignalGroupButton.Enable = 'off';
            app.RemoveFromSignalGroupButton.Enable = 'off';
            app.HighlightSignalInModelButton.Enable = 'off';
            app.HighlightSignalInModelButton.Tooltip = '';
            app.SDIOpenButton.Enable = 'off';
            app.SDIStreamButton.Enable = 'off';
            app.SDIStreamButton.Tooltip = {''};
            
            app.ParametersTable.UserData = [];
            app.ParametersTable.Data = [];
            app.ParametersTable.Enable = 'off';
            app.HighlightParameterInModelButton.Enable = 'off';
            app.HighlightParameterInModelButton.Tooltip = '';
        end

    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % Add initial icons.
            %
            app.ConnectDisconnectButton.Icon           = app.connectedIcon;
            app.LoadApplicationButton.Icon             = app.loadIcon;
            app.StartStopButton.Icon                   = app.runIcon;
            app.FilterCurrentSystemAndBelowButton.Icon = app.currentSystemIcon;
            app.AddScopeButton.Icon                    = app.addIcon;
            app.DeleteScopeButton.Icon                 = app.deleteIcon;
            app.SDIStreamButton.Icon                   = app.logSignalIcon;
            app.SDIOpenButton.Icon                     = app.openSDIIcon;
            app.HighlightParameterInModelButton.Icon   = app.hiliteInModelIcon;
            app.HighlightSignalInModelButton.Icon      = app.hiliteInModelIcon;
            app.RemoveFromSignalGroupButton.Icon       = app.removeRowIcon;
            app.AddToSignalGroupButton.Icon            = app.addRowIcon;
            app.HelpButton.Icon                        = app.helpIcon;
            
            
            
            % Add Tooltips JM
            app.AddToSignalGroupButton.Tooltip            = app.addToSignalGroupButtonTooltip;
            app.RemoveFromSignalGroupButton.Tooltip       = app.removeFromSignalGroupButtonTooltip;
            app.TargetsDropDown.Tooltip                   = app.targetsDropDownTooltip;
            app.ConnectDisconnectButton.Tooltip           = app.connectedTooltip;
            app.LoadApplicationButton.Tooltip             = app.loadApplicationButtonTooltip;
            app.StartStopButton.Tooltip                   = app.startTooltip;
            app.StopTimeField.Tooltip                     = app.stopTimeFieldTooltip;
            app.HelpButton.Tooltip                        = app.helpButtonTooltip;
            app.FilterContentsEditField.Tooltip           = app.filterSignalsTooltip;
            app.FilterCurrentSystemAndBelowButton.Tooltip = app.contentsBelowTooltip;
            app.SDIStreamButton.Tooltip                   = {''};
            app.HighlightSignalInModelButton.Tooltip      = app.highlightSignalButtonTooltip;
            app.HighlightParameterInModelButton.Tooltip   = app.highlightParameterButtonTooltip;
            
            
            
            % Delete the scope axes, it is only needed to get the
            % proper position of scopes added by user.
            %
            app.scopePos = app.ScopeAxes.Position;
            delete(app.ScopesGroup.SelectedTab);
            app.ScopesGroup.Children = [];
            
            % Add all available signal groups.
            %
            app.signalsGroupMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            app.signalsGroupMap('<no selection>') =  SimulinkRealTime.SignalList; % empty signal list
            
            % Add all available targets.
            %
            app.TargetsDropDown.Items = {'Manage Target Computers ...'};
            targets = SimulinkRealTime.internal.targets;
            targetNames = targets.getTargetNames;
            for i=1:length(targetNames)
                app.addTarget(targetNames{i});
            end
            
            % Create a timer for scopes.
            %
            app.signalTimer = timer('Period', 0.1, 'ExecutionMode', 'fixedRate', ...
                'StartDelay', 0, 'TimerFcn', @(timerObj, event)app.signalTimerCB(timerObj));
            
            % Initially select default target.
            %
            defaultTargetName = app.getSLRTDefaultTargetName();
            app.TargetsDropDown.Value = defaultTargetName;
            app.updateGUIForSelectedTarget();
            app.updateGUIForTargetApplicationFilter(defaultTargetName);
            
            % Listen for targets added, removed, and renamed.
            %
            app.addTargetListener    = addlistener(targets, 'EnvAdded',   @app.targetAddedCB);
            app.removeTargetListener = addlistener(targets, 'EnvRemoved', @app.targetRemovedCB);
            
        end

        % Callback function
        function SignalsTableCellEdit(app, event)
            sels = cell2mat(app.SignalsTable.Data(:,1));
            if ~any(sels)
                app.AddToSignalGroupButton.Enable = 'off';
                app.HighlightSignalInModelButton.Enable = 'off';
                app.HighlightSignalInModelButton.Tooltip= {''};
            else
                app.AddToSignalGroupButton.Enable = 'on';
                app.HighlightSignalInModelButton.Enable = 'on';
                app.HighlightSignalInModelButton.Tooltip = app.highlightSignalButtonTooltip;
            end
        end

        % Button pushed function: ConnectDisconnectButton
        function ScopeModeButtonGroupSelectionChanged(app, event)
            selectedButton = app.ScopeModeButtonGroup.SelectedObject;
            selectedTargetName = app.getSelectedTargetName();
            target = app.getTarget(selectedTargetName);
            scIdx = find(strcmp({target.scopes.name}, app.ScopesGroup.SelectedTab.Title));
            target.scopes(scIdx).mode = selectedButton.Text;
            app.targetMap(selectedTargetName) = target;
        end

        % Value changed function: TargetsDropDown
        function TargetsDropDownValueChanged(app, event)
            app.updateGUIForSelectedTarget();
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create SimulinkRealTimeExplorerUIFigure and hide until all components are created
            app.SimulinkRealTimeExplorerUIFigure = uifigure('Visible', 'off');
            app.SimulinkRealTimeExplorerUIFigure.AutoResizeChildren = 'off';
            app.SimulinkRealTimeExplorerUIFigure.Position = [-1350 100 1284 731];
            app.SimulinkRealTimeExplorerUIFigure.Name = 'Simulink Real-Time Explorer';
            app.SimulinkRealTimeExplorerUIFigure.Resize = 'off';

            % Create Panel
            app.Panel = uipanel(app.SimulinkRealTimeExplorerUIFigure);
            app.Panel.AutoResizeChildren = 'off';
            app.Panel.Position = [11 11 1268 711];

            % Create TargetPanel
            app.TargetPanel = uipanel(app.Panel);
            app.TargetPanel.AutoResizeChildren = 'off';
            app.TargetPanel.BorderType = 'none';
            app.TargetPanel.Position = [40 658 1152 49];

            % Create ConnectDisconnectButton
            app.ConnectDisconnectButton = uibutton(app.TargetPanel, 'push');
            app.ConnectDisconnectButton.ButtonPushedFcn = createCallbackFcn(app, @ScopeModeButtonGroupSelectionChanged, true);
            app.ConnectDisconnectButton.Position = [224 11 134 31];
            app.ConnectDisconnectButton.Text = 'Connect';

            % Create LoadApplicationButton
            app.LoadApplicationButton = uibutton(app.TargetPanel, 'push');
            app.LoadApplicationButton.Position = [368 11 134 31];
            app.LoadApplicationButton.Text = 'Load Application';

            % Create StartStopButton
            app.StartStopButton = uibutton(app.TargetPanel, 'push');
            app.StartStopButton.Position = [511 11 40 31];
            app.StartStopButton.Text = '';

            % Create StopTimeField
            app.StopTimeField = uieditfield(app.TargetPanel, 'text');
            app.StopTimeField.Position = [561 15 63 22];

            % Create TargetsDropDown
            app.TargetsDropDown = uidropdown(app.TargetPanel);
            app.TargetsDropDown.Items = {};
            app.TargetsDropDown.ValueChangedFcn = createCallbackFcn(app, @TargetsDropDownValueChanged, true);
            app.TargetsDropDown.Position = [7 11 210 31];
            app.TargetsDropDown.Value = {};

            % Create ApplicationTree
            app.ApplicationTree = uitree(app.Panel);
            app.ApplicationTree.Position = [46 276 211 342];

            % Show the figure after all components are created
            app.SimulinkRealTimeExplorerUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ExplorerA

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.SimulinkRealTimeExplorerUIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.SimulinkRealTimeExplorerUIFigure)
        end
    end
end