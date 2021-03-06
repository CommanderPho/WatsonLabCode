function tc = linearInterp(t,x,val)

% Linear interpolation to find the "true" time when x cross val. Direction above;

ix = find(x>val);
if length(ix)
	ix = ix(1);
	if ix>1
		t1 = t(ix-1);
		t2 = t(ix);
		y1 = x(ix-1);
		y2 = x(ix);
		
		tc = (t2 - t1)/(y2 - y1)*(val - y1) + t1; 
	else
		tc = t(1);
	end
else
	tc = t(end);
end
	