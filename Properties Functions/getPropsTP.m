function [s, rho, h] = getPropsTP(T,p,substance,mode,check)
% find entropy, enthalpy, and density of fluids

% Inputs:
% T: Temperature[K]
% p: pressure[kPa]
% Substance: working fluid for the system
% Mode: 1(constant property model), 2(use of FIT),3(use of REFPROP),
%       or property tables for interpolation
% check: tells which properties are requested - 1(only find enthalpy),
%        2(enthalpy, density, and entropy)

% Output array:
% s: entropy[J/kg-K]
% rho: density[kg/m^3]
% h: enthalpy[J/kg]

modesize = size(mode);

if check == 1
    % find enthalpy
    
    if mode == 1
        c_p = 1000;         % cp value estimation [J/kg-K]
        h = c_p*T;          % find enthalpy with h0 at 0K
    elseif mode == 2
        h = CO2_TP(T,p,'enth');     % returns enthlapy [kJ/kg]
        h = h*1000;                 % convert enthalpy to [J/kg]
    elseif mode == 3
        h = zeros(1,length(T));
        p = ones(1,length(T)).*p;
        tf = iscell(substance(1));
        if tf == 1
            % mixture
            for i = 1:length(T)
                h(i) = refpropm('H','T',T(i),'P',p(i),substance{1},substance{2},substance{3}); % returns enthalpy [J/kg]
            end
        else
            % pure fluid
            for i = 1:length(T)
                h(i) = refpropm('H','T',T(i),'P',p(i),substance); % returns enthalpy [J/kg]
            end
        end
    elseif modesize(1) > 1
        h = propertiesInterp('h','T',T,p,mode);
    end
    s = NaN;
    rho = NaN;
    
elseif check == 2
    % find enthalpy, density, and entropy
    
    if mode == 1              % constant properties
        c_p = 1000;           % cp value estimation [J/kg-K]
        h = c_p*T;            % find enthalpy with h0 at 0K
        R = 188.9;            % specific gas constant for CO2 [J/kg-K]
        rho = p./(R*T);       % Ideal gas law
        Tref = 273.15;        % Reference Temperature [K]
        pref = 100;           % Reference Pressure [kPa]
        s = c_p*log(T/Tref)-R*log(p/pref);     % find entropy [J/kg-K]
    elseif mode == 2
        [s, rho, h] = CO2_TP(T,p,'entr','dens','enth');
        % returns entropy [kJ/kg-K], density [kg/m3], enthlapy [kJ/kg]
        s = s*1000;           % convert entropy to [J/kg-K]
        h = h*1000;           % convert enthalpy to [J/kg]
    elseif mode == 3
        s = zeros(1,length(T));
        rho = zeros(1,length(T));
        h = zeros(1,length(T));
        p = ones(1,length(T)).*p;
        tf = iscell(substance(1));
        if tf == 1
            % mixture
            for i = 1:length(s)
                [s(i), rho(i), h(i)] = refpropm('SDH','T',T(i),'P',p(i),substance{1},substance{2},substance{3});
            end
        else
            % pure fluid
            for i = 1:length(s)
                [s(i), rho(i), h(i)] = refpropm('SDH','T',T(i),'P',p(i),substance);
            end
        end
    elseif modesize(1) > 1
        h = propertiesInterp('h','T',T,p,mode);
        rho = propertiesInterp('d','T',T,p,mode);
        s = propertiesInterp('s','T',T,p,mode);
    end
    
end

end