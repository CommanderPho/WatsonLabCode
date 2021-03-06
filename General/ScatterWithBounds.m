function ScatterWithBounds(data,x_lim,y_lim)

% ScatterWithBounds(data,x_lim,y_lim)
% 
% Just makes it easier to scatter plot two vectors around a trendline
% (polynomial fit) and between 95% confidence bounds. Linear correlation
% values R and P are also displayed.
%
% USAGE ___________________________________________________________________
% data -> 2-D matrix with two columns, one for each variable.
%
% x_lim and y_lim -> Optional inputs. They are just the "within-brackets"
% information given to xlim and ylim to delimit graph axes. Example:
% "ScatterWithBounds(data,[0.1 1],[0.2 2]). Including only one optional
% argument will control xlim only, while leaving ylim as default. Skipping
% both will leave both as default.
%
% LSBuenoJr _______________________________________________________________

%% Statistics 
[R,P] = corrcoef(data(:,1),data(:,2));

%% Figure
fitresult = fit(data(:,1),data(:,2),'poly1');

scatter(data(:,1),data(:,2));hold on;plot(fitresult,'k');
plot(data(:,1),predint(fitresult,data(:,1),0.95),'k.');
set(legend,'visible','off');ylabel([]);xlabel([])

text(0.8,0.15,['R = ' num2str(round(R(2,1),3))],'Units','normalized')
if P(2,1) < 0.001
    text(0.8,0.10,'P < 0.001','Units','normalized')
else
    text(0.8,0.10,['P = ' num2str(round(P(2,1),3))],'Units','normalized')
end

switch nargin
    case 3
        xlim(x_lim);ylim(y_lim)
    case 2
        xlim(x_lim)
    case 1
end
end