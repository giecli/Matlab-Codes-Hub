function [minMass,UA,UA_min_original,mass_reactor,mass_recuperator,mass_radiator,m_dot] = minRadRecMass( A_panel,desiredPower,p1,T4,PR_c,T_amb,fluid,mode,check,tolerance,NucFuel,RecupMatl )
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
% Mode: 1(constant property model),2(use of FIT),3(use of REFPROP)
% check: 1 (only provide minMass, UA, UA_min) 2 (provide all outputs)
% tolerance: 1 (vary accurate tolerance), 2 (less accurate tolerance - for
% use in bound finding)
% NucFuel: 'UO2' for uranium oxide (near term), 'UW' for uranium tunsten
% (exotic)
% RecupMatl: 'IN' for Inconel, 'SS' for stainless steel,
%   for recuperator far term exploration, use 'U#' -
%   uninsulated, # of units, 'I#' -insulated, # of units
%   (all units are Inconel for these cases)

% Outputs:2
% minMass: lowest possible total system mass for system with desired
% power output and radiator area

% find minimum UA which gives desired power output
[ UA_min_original,m_dot_original ] = minimumUA(desiredPower,p1,T4,PR_c,A_panel,...
    T_amb,fluid,mode);

% set dew point temperature and T1 at minimum UA (maximum T1)
[~,~,~,~,~,~,~,~,...
    ~,T1_max,~,~,~,~,~,~,~,~,~,~,~,~,...
    ~,~,~,~,~] = BraytonCycle(m_dot_original,p1,T4,PR_c,UA_min_original,...
    A_panel,T_amb,fluid,mode,0);

TDewPoint = mode(1,91);
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
        UA = linspace(UA_min,UA_max,5);
        
        % preallocate space
        mass_total = zeros(1,length(UA));
        m_dotcycle_max = m_dot_original;
        for i = 1:length(UA)
            [ mass_total(i),~,~,~,m_dot_last ] = totalMass( UA(i),desiredPower,p1,T4,PR_c,A_panel,...
                T_amb,fluid,mode,m_dotcycle_max,options1,NucFuel,RecupMatl);
            m_dotcycle_max = m_dot_last;
            
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
            UA_max = UA(end);
            UA_min = UA(end - 1);
            break
        else
            if inde == length(UA)
                UA_max = UA(length(UA))*2;
                UA_min = UA(length(UA-1));
            else
                a = 0;
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
            UA_maxValid = fzero(@UAatTDewPoint,[UA_min_original,UA_max],[],desiredPower,p1,T4,PR_c,A_panel,...
                T_amb,fluid,mode,NucFuel,RecupMatl,TDewPoint,m_dot_original);
            [ minMass,mass_reactor,mass_recuperator,mass_radiator,m_dot ] = totalMass( UA_maxValid,desiredPower,p1,T4,PR_c,A_panel,...
                T_amb,fluid,mode,m_dot_original,[],NucFuel,RecupMatl);
        else
            options2 = [];
            [UA,minMass] = fminbnd(@totalMass,UA_min,UA_max,[],desiredPower,p1,T4,PR_c,A_panel,...
                T_amb,fluid,mode,m_dot_original,options2,NucFuel,RecupMatl);
            [ ~,mass_reactor,mass_recuperator,mass_radiator,m_dot ] = totalMass( UA,desiredPower,p1,T4,PR_c,A_panel,...
                T_amb,fluid,mode,m_dot_original,options2,NucFuel,RecupMatl);
            % check T1 is above Dew Point and decrease UA if it is not
            % (this happens when UA causing T1 below Dew Point and UA
            % causing min mass are very close
            [~,~,~,~,~,~,~,~,...
                ~,T1,~,~,~,~,~,~,~,~,~,~,~,~,...
                ~,~,~,~,~] = BraytonCycle(m_dot,p1,T4,PR_c,UA,...
                A_panel,T_amb,fluid,mode,0);
            if T1 < TDewPoint
                UA_maxValid = fzero(@UAatTDewPoint,[UA_min_original,UA_max],[],desiredPower,p1,T4,PR_c,A_panel,...
                    T_amb,fluid,mode,NucFuel,RecupMatl,TDewPoint,m_dot_original);
                [ minMass,mass_reactor,mass_recuperator,mass_radiator,m_dot ] = totalMass( UA_maxValid,desiredPower,p1,T4,PR_c,A_panel,...
                    T_amb,fluid,mode,m_dot_original,[],NucFuel,RecupMatl);
            end
        end
    elseif tolerance == 2
        %         options2 = optimset('TolX',0.1);
        % if high accuracy in tolerance is not required, use minimum mass
        % and corresponding UA from bound finding
        UA = UA(inde);
        minMass = mass_total(inde);
        mass_reactor = inf;
        mass_recuperator = inf;
        mass_radiator = inf;
        m_dot = inf;
    end
    
    
    
    
    
%     if check == 2
%         
%         
%         
%     else
%         mass_reactor = inf;
%         mass_recuperator = inf;
%         mass_radiator = inf;
%         m_dot = inf;
%     end
    
end







    function [T1_error] = UAatTDewPoint (UA_maxValidGuess,desiredPower,p1,T4,PR_c,A_panel,...
            T_amb,fluid,mode,NucFuel,RecupMatl,TDewPoint_fcn,m_dot_max)
        [ ~,~,~,~,m_dot_fcn ] = totalMass( UA_maxValidGuess,desiredPower,p1,T4,PR_c,A_panel,...
            T_amb,fluid,mode,m_dot_max,[],NucFuel,RecupMatl);
        [~,~,~,~,~,~,~,~,...
            ~,T1_fcn,~,~,~,~,~,~,~,~,~,~,~,~,...
            ~,~,~,~,~] = BraytonCycle(m_dot_fcn,p1,T4,PR_c,UA_maxValidGuess,...
            A_panel,T_amb,fluid,mode,0);
        T1_error = T1_fcn-TDewPoint_fcn;
    end


end

