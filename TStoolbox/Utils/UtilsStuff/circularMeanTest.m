function [H,pval] = circularMeanTest(theta,mu0,varargin)

% USAGE
%
%    [H,P] = circularMeanTest(t,theta)
%	tests that the mean direction of samples theta (in radian) is equal to mu0
%    H and P are the boolean value of success (at P<0.05 if not specified) and the p-value, respectively
% 
% From Watson 1983, in Fischer p116
% adapted to matlab by Adrien Peyrache, 2007


% Default parameters
testType=0;
B =1000; %number of iterations in bootstrap
alpha = 0.05; %significancy level

while length(varargin)>1

	switch varargin{1}
		case 'Test'
			switch varargin{2}
				case 'Watson'
					testType=1;
				case 'Bootstrap'
					testType=2;
				otherwise
				warning(['Unknown test type, ' varargin{2}])
			end
		
		otherwise
			warning(['Unknow option name, ' varargin{1}])
	end

	varargin = varargin(3:end);

end

n = length(theta);
if n==0
	error('No data')
end

if testType==0
	display('No test specified');
	if n>25
		display('Large sample test, Watson 1983');
		testType = 1;
	else
		display('Small sample test, Bootstrap, Fischer&Powell 1989');
		testType = 2;
	end	
end


% Now the test
[mu dummy dummy dummy sigma]= CircularMean(theta);
S = sin(mu-mu0)/sigma;

if testType==1
	
	pval = 1-normcdf(abs(S),0,1);

elseif testType==2

	phi = theta - (mu-mu0);

	for i=1:B

		perm = floor(n*rand(n,1))+1;
		[muB dummy dummy dummy sigmaB]= CircularMean(phi(perm));
		SB(i) = sin(muB-mu)/sigmaB;

	end
	
	u = normcdf(abs(SB),0,1);
	us = sort(u);
	tmp = find((us-abs(S))<0);
	if length(tmp)>0
		pval = tmp(end)/B;
	else
		pval = 1;
	end

end


H=0;

if pval<0.05
	H=1;
end
