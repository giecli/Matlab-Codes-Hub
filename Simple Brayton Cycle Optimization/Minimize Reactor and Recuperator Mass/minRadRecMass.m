function [minMass,UA,UA_min_original,mass_reactor,mass_recuperator,mass_radiator,m_dot] = minRadRecMass( A_panel,desiredPower,p1,T4,PR_c,T_amb,fluid,mode,tolerance,NucFuel,RecupMatl )
% gives minimum system mass for a cycle with a specified radiator area
% and power output

A_panel

% Inputs:
% desiredpower: specified power for the system
% p1: flow pressure at inlet of the compressor [kPa]
% T4: Temp at turbine inlet [K]
% PR_c: pressure ratio of the compressor
% A_panel: area of radiator panel [m2]
% T_amb: ambient temp for radiator [K]
% fluid: working fluid for the system
% Mode: 1(constant property model), 2(use of FIT),3(use of REFPROP), 
%       or property tables for interpolation
% tolerance: 1 (vary accurate tolerance), 2 (less accurate tolerance - for
% use in bound finding)
% NucFuel: 'UO2' for uranium oxide (near term), 'UW' for uranium tunsten
% (exotic)
% RecupMatl: 'IN' for Inconel, 'SN' for near term stainless steel, 'SF' for
%            far term stainless steel

% Outputs:2
% minMass: lowest possible total system mass for system with desired
% power output and radiator area
% UA: recuperator conductance for optimum cycle [W/K]
% UA_min: minimum recuperator conductance for specified radiator panel area
% [W/K]
% mass_reactor: reactor mass of optimum cycle [kg]
% mass_recuperator: recuperator mass of optimum cycle [kg]
% mass_radiator: radiator mass [kg]
% m_dot: mass flow rate of optimum cycle [kg/s]

% find minimum UA which gives desired power output
[ UA_min_original,m_dot_original ] = minimumUA(desiredPower,p1,T4,PR_c,A_panel,...
    T_amb,fluid,mode);

% find T1 at minimum UA (maximum T1 for this Apanel)
[~,~,~,~,~,~,~,~,...
    ~,T1_max,~,~,~,~,~,~,~,~,~,~,~,~,...
    ~,~,~,~,~] = BraytonCycle(m_dot_original,p1,T4,PR_c,UA_min_original,...
    A_panel,T_amb,fluid,mode,0);

% find dew point temperature
modesize = size(mode);
if mode == 2
    TDewPoint = 304.25; % [K]
elseif mode == 3
    TDewPoint = refpropm('T','C',0,' ',0,fluid);
elseif modesize(1) > 1
    TDewPoint = mode(1,91);
end

% set logical check for minimum temperature below dew point to false
% initially
TBelowDewPoint = 0;


if isnan(UA_min_original) || isnan(m_dot_original) || T1_max < TDewPoint
    minMass = NaN;
    UA = Inf;
    UA_min_original = Inf;
    mass_reactor = inf;
    mass_recuperator = inf;
    mass_radiator = inf;
    m_dot = inf;
else
    
    
    %%%%%%%%%%%%%% find bounds for mass minimization %%%%%%%%%%%%%%%%%%
    UA_max = UA_min_original*2;
    UA_min = UA_min_original + 1e-8;
    options1 = optimset('TolX',1e-5);
    a = 1;
    loopcount = 1;
    
    while a ==1
        UA = linspace(UA_min,UA_max,20);
        
        % preallocate space
        mass_total = zeros(1,length(UA));
        m_dotcycle_max = zeros(1,length(UA));
        m_dotcycle_max(1) = m_dot_original;
        for i = 1:length(UA)
            [ mass_total(i),~,~,~,m_dot_last ] = totalMass( UA(i),desiredPower,p1,T4,PR_c,A_panel,...
                T_amb,fluid,mode,m_dotcycle_max(i),options1,NucFuel,RecupMatl);
            m_dotcycle_max(i+1) = m_dot_last;
            
            [~,~,~,~,~,~,~,~,...
                ~,T1,~,~,~,~,~,~,~,~,~,~,~,~,...
                ~,~,~,~,~] = BraytonCycle(m_dot_last,p1,T4,PR_c,UA(i),...
                A_panel,T_amb,fluid,mode,0);
            
            if i > 1 && mass_total(i) > mass_total(i-1)
                % mass is getting larger, the solution has
                % already been passed -no need to calculate the other
                % values (starting with the minimum UA, the total mass
                % should start large, reach a minimum, and then go up again
                mass_total(i+1:end) = [];
                a = 0;
                break
            elseif i > 1 && T1 < TDewPoint
                % temperature is below dew point, no need to calculate
                % other values
                TBelowDewPoint = 1;
                mass_total(i+1:end) = [];
                break
            end
        end
        
        [~,inde] = min(mass_total);
        
        if TBelowDewPoint == 1
            UA_max = UA(length(mass_total));
            UA_min = UA(length(mass_total) - 1);
            m_dot_max = m_dotcycle_max(length(mass_total) - 1);
            break
        else
            if a == 0
                UA_max = UA(length(mass_total));
                UA_min = UA(1);
                m_dot_max = m_dot_original;
                break
            elseif inde == length(UA)
                UA_max = UA(length(UA))*2;
                UA_min = UA(length(UA-1));
            end
            
            if loopcount > 50 && a ==1
                fprintf(2, 'minRadRecMass: unable to find UA boundaries \n \n');
                UA_max = NaN;
                UA_min = NaN;
                break
            end
        end
        
        loopcount = loopcount + 1;
    end
    
    %%%%%%%%%%%%%%%%%%%%%%% end bound find %%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % find recuperator conductance for cycle with minimum mass
    
    if tolerance == 1
        % if high tolerance is required, find exact minimum mass or
        % minimum temperature (if Dew Point is reached)
        if TBelowDewPoint == 1
            options = optimset('TolX', 1e-4);
            UA_maxValid = fzero(@UAatTDewPoint,[UA_min,UA_max],options,desiredPower,p1,T4,PR_c,A_panel,...
                T_amb,fluid,mode,NucFuel,RecupMatl,TDewPoint,m_dot_max);
            [ minMass,mass_reactor,mass_recuperator,mass_radiator,m_dot ] = totalMass( UA_maxValid,desiredPower,p1,T4,PR_c,A_panel,...
                T_amb,fluid,mode,m_dot_max,[],NucFuel,RecupMatl);
            UA = UA_maxValid;
        else
            options2 = [];
            [UA,minMass] = fminbnd(@totalMass,UA_min,UA_max,[],desiredPower,p1,T4,PR_c,A_panel,...
                T_amb,fluid,mode,m_dot_max,options2,NucFuel,RecupMatl);
            [ ~,mass_reactor,mass_recuperator,mass_radiator,m_dot ] = totalMass( UA,desiredPower,p1,T4,PR_c,A_panel,...
                T_amb,fluid,mode,m_dot_max,options2,NucFuel,RecupMatl);
            % check T1 is above Dew Point and decrease UA if it is not
            % (this happens when UA causing T1 below Dew Point and UA
            % causing min mass are very close
            [~,~,~,~,~,~,~,~,...
                ~,T1,~,~,~,~,~,~,~,~,~,~,~,~,...
                ~,~,~,~,~] = BraytonCycle(m_dot,p1,T4,PR_c,UA,...
                A_panel,T_amb,fluid,mode,0);
            if T1 < TDewPoint
                options = optimset('TolX', 1e-4);
                UA_maxValid = fzero(@UAatTDewPoint,[UA_min_original,UA_max],options,desiredPower,p1,T4,PR_c,A_panel,...
                    T_amb,fluid,mode,NucFuel,RecupMatl,TDewPoint,m_dot_max);
                [ minMass,mass_reactor,mass_recuperator,mass_radiator,m_dot ] = totalMass( UA_maxValid,desiredPower,p1,T4,PR_c,A_panel,...
                    T_amb,fluid,mode,m_dot_max,[],NucFuel,RecupMatl);
                UA = UA_maxValid;
            end
        end
    elseif tolerance == 2
        % if high accuracy in tolerance is not required, use minimum mass
        % and corresponding UA from bound finding
        UA = UA(inde);
        minMass = mass_total(inde);
        mass_reactor = inf;
        mass_recuperator = inf;
        mass_radiator = inf;
        m_dot = inf;
    end

    
end


    function [T1_error] = UAatTDewPoint (UA_maxValidGuess,desiredPower,p1,T4,PR_c,A_panel,...
            T_amb,fluid,mode,NucFuel,RecupMatl,TDewPoint_fcn,m_dot_max)
        % finds maximum UA - location where minimum UA gives T1 = TDewPoint
        [ ~,~,~,~,m_dot_fcn ] = totalMass( UA_maxValidGuess,desiredPower,p1,T4,PR_c,A_panel,...
            T_amb,fluid,mode,m_dot_max,[],NucFuel,RecupMatl);
        [~,~,~,~,~,~,~,~,...
            ~,T1_fcn,~,~,~,~,~,~,~,~,~,~,~,~,...
            ~,~,~,~,~] = BraytonCycle(m_dot_fcn,p1,T4,PR_c,UA_maxValidGuess,...
            A_panel,T_amb,fluid,mode,0);
        T1_error = T1_fcn-TDewPoint_fcn;
    end


end

