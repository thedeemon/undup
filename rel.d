module rel;
import std.typecons, std.range, std.container, std.stdio, std.string, std.algorithm : map;
enum Rel { Unknown, ImNewer, ImOlder, Same, Different }

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

class InferenceError : Error 
{
	int[] abc;
	this(int[] ijk, string file = __FILE__, size_t line = __LINE__) { super("InferenceError", file, line, null); abc = ijk; }
	override string toString() { return format("InferenceError %s", abc);}
}

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
		SList!(Tuple!(int,int)) added;
		set(i,j, r);
		added.insert(tuple(i,j));		
		while(!added.empty) {
			auto ij = added.removeAny();
			i = ij[0]; j = ij[1];
			auto rij = rel[i][j];
			foreach(rule; rules) 
				if (rule[0]==rij)
					foreach(k; 0..N)
						if (rel[j][k]==rule[1]) {
							if (rel[i][k]==Rel.Unknown) {
								set(i,k, rule[2]);
								//added.insert(tuple(i,k));
							} else
								if(rel[i][k] != rule[2]) {
									writeln("RelMat.add: inference rule violation found(1)");
									writefln("rule: %s", rule);
									writefln("i=%s j=%s k=%s rel[ij]=%s rel[jk]=%s rel[ik]=%s", i,j,k, rel[i][j], rel[j][k], rel[i][k]);
									throw new InferenceError([i,j,k]);
								}
						}
			foreach(rule; rules)
				if (rule[1]==rij) {
					auto ir0 = inv(rule[0]), ir2 = inv(rule[2]);
					foreach(k; 0..N)
						if (rel[i][k]==ir0) {
							if (rel[j][k]==Rel.Unknown) {
								set(k,j, rule[2]);
								//added.insert(tuple(k,j));
							} else
								if(rel[j][k] != ir2) {
									writeln("RelMat.add: inference rule violation found(2)");
									writefln("rule: %s", rule);
									writefln("k=%s i=%s j=%s rel[ki]=%s rel[ij]=%s rel[kj]=%s", k,i,j, rel[k][i], rel[i][j], rel[k][j]);
									throw new InferenceError([k,i,j]);
								}
						}//if rule[0]
				} //if rule[1]
		}//loop added
	}//add()
}
