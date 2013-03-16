module rel;
import std.typecons, std.range, std.container, std.stdio, std.string, std.algorithm : map;
enum Rel : byte { Unknown, ImNewer, ImOlder, Same, Different }

Rel inv(Rel x)
{
	switch(x) {
		case Rel.ImNewer: return Rel.ImOlder;
		case Rel.ImOlder: return Rel.ImNewer;
		default: return x;
	}
}

class RelCache {
	Rel[Tuple!(int,int)] cache;

	void add(int leftID, int rightID, Rel r)
	{
		if (r == Rel.Different) return; //save memory, don't cache Different
		if (leftID <= rightID)
			cache[tuple(leftID, rightID)] = r;
		else
			cache[tuple(rightID, leftID)] = inv(r);
	}

	Rel get(int leftID, int rightID)
	{
		if (leftID <= rightID)
			return cache.get(tuple(leftID, rightID), Rel.Unknown);
		else
			return cache.get(tuple(rightID, leftID), Rel.Unknown).inv;
	}
}


/*
A < B < C => A < C
A < B = C => A < C
A < B > C => A ? C
A < B # C => A ? C
A > B < C => A ? C
A > B = C => A > C
A > B > C => A > C
A > B # C => A ? C
A = B < C => A < C
A = B = C => A = C
A = B > C => A > C
A = B # C => A # C
A # B < C => A ? C
A # B = C => A # C
A # B > C => A ? C
A # B # C => A ? C
*/

immutable Rel[3][] rules = [
	[Rel.ImOlder, Rel.ImOlder,  Rel.ImOlder],
	[Rel.ImOlder, Rel.Same,  Rel.ImOlder],
	[Rel.ImNewer, Rel.Same,  Rel.ImNewer],
	[Rel.ImNewer, Rel.ImNewer,  Rel.ImNewer],
	[Rel.Same, Rel.ImOlder,  Rel.ImOlder],
	[Rel.Same, Rel.Same,  Rel.Same],
	[Rel.Same, Rel.ImNewer,  Rel.ImNewer],
	[Rel.Same, Rel.Different,  Rel.Different],
	[Rel.Different, Rel.Same,  Rel.Different]
];

class RelMat {
	int N;
	Rel[][] rel;
	int curRow;

	this(int n) 
	{
		N = n;
		Rel[] mkrow(int i) { return iota(0,n).map!((int j) => i==j ? Rel.Same : Rel.Unknown).array; }
		rel = iota(0,n).map!mkrow.array;
		curRow = 1;
	}

	bool nextPair(out int i, out int j)
	{
		foreach(y; curRow..N)
			foreach(x; 0..y)
				if (rel[y][x]==Rel.Unknown) {
					i = y; j = x; curRow = y;
					return true;
				}
		return false;
	}

	private void set(int i, int j, Rel r)
	{
		rel[i][j] = r;
		rel[j][i] = inv(r);		
	}

	void add(int i, int j, Rel r)
	{
		set(i,j, r);
		auto rij = rel[i][j];
		foreach(rule; rules) 
			if (rule[0]==rij)
				foreach(k; 0..N)
					if (rel[j][k]==rule[1] && rel[i][k]==Rel.Unknown) 
						set(i,k, rule[2]);					
		foreach(rule; rules)
			if (rule[1]==rij) {
				auto ir0 = inv(rule[0]), ir2 = inv(rule[2]);
				foreach(k; 0..N)
					if (rel[i][k]==ir0 && rel[j][k]==Rel.Unknown) 
						set(k,j, rule[2]);					
			} 
	}
}
