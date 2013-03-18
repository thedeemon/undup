module box;
import fileops, rel, std.algorithm, std.array, std.string, std.typecons, dfl.drawing : Rect;

immutable small_size = 4_000_000;
alias DrawFun = void delegate(double x, double y, double w, double h, Rel, Box);

string sizeString(long sz)
{
	enum long MB = 1024 * 1024; 
	enum long GB = 1024 * MB;
	if (sz >= 10*GB) return format("%s GB", sz / GB);
	if (sz >= GB) return format("%s.%s GB", sz / GB, (sz / (GB/10)) % 10);
	if (sz >= 10*MB) return format("%s MB", sz / MB);
	if (sz >= MB) return format("%s.%s MB", sz / MB, (sz / (MB/10)) % 10);
	return format("%s", sz);
}

class Box {
	IFSObject item;
	double x,y, w,h;
	Box[] subs;
	Box parent;
	SimilarBoxes similar;

	this(IFSObject fsobject, Box[] _subs)
	{
		item = fsobject; subs = _subs;
		foreach(bx; subs)
			bx.parent = this;
	}

	@property long size() { return item.getSize(); }

	@property string sizeString() { return item.getSize.sizeString; }

	void place(double x0, double y0, double width, double height)
	{
		x = x0; y = y0; w = width; h = height;
		if (subs !is null) Layout(subs, x0, y0, width, height);
	}

	void draw(DrawFun drawrect, SimilarBoxes delegate(IFSObject) getsim)
	{
		SimilarBoxes sb = getsim(item);	
		Rel r = Rel.Unknown;
		if (sb !is null) {
			similar = sb;
			r = sb.status;
		}

		if (subs.length==0) 
			drawrect(x,y,w,h, r, this);
		else
			if (r == Rel.Unknown)
				foreach(bx; subs)
					bx.draw(drawrect, getsim);
			else
				foreach(bx; subs)
					bx.draw2(drawrect, sb);
	}

	void draw2(DrawFun drawrect, SimilarBoxes sb)
	{
		similar = sb;
		if (subs.length==0) 
			drawrect(x,y,w,h, sb.status, this);
		else
			foreach(bx; subs)
				bx.draw2(drawrect, sb);
	}

	Box findByPoint(int mx, int my, Box curParent, ref Box resultParent)
	{
		if (mx < x || my < y || mx >= (x+w) || my >= (y+h)) return null;
		if (subs is null || subs.length == 0) {
			resultParent = curParent;
			return this;
		}
		foreach(bx; subs) {
			auto p = bx.findByPoint(mx,my, this, resultParent);
			if (p !is null) return p;
		}
		return null;
	}

	Rect rect()
	{
		return Rect(cast(int)x, cast(int)y, cast(int)w, cast(int)h);
	}

	Box[] path()
	{
		Box[] bxs;
		addAncestors(bxs);
		return bxs;
	}

	private void addAncestors(ref Box[] bxs)
	{
		if (parent !is null)
			parent.addAncestors(bxs);
		bxs ~= this;
	}

	void addDirsToMap(ref Box[int] index)
	{
		int id = item.getID();
		if (id > -1) {
			index[id] = this;
			if (subs !is null)
				foreach(bx; subs)
					bx.addDirsToMap(index);
		}
	}

	void addFilesToMap(ref Box[string] index)
	{
		int id = item.getID();
		if (id == -1) {
			if (item.fullName == "...") return;
			index[item.fullName] = this;
		}
		if (subs !is null)
			foreach(bx; subs)
				bx.addFilesToMap(index);
	}
}

Box boxOfDir(DirInfo di)
{
	long smallsizes = 0;
	Box[] subs;
	foreach(d; di.subdirs)
		if (d.getSize() > small_size) subs ~= boxOfDir(d);
		else smallsizes += d.getSize();
	foreach(f; di.files)
		if (f.size > small_size) subs ~= new Box(new PFileInfo(f, di), null);
		else smallsizes += f.size;

	if (subs.length > 0) {
		if (smallsizes > 0)
			subs ~= new Box(new Dummy(smallsizes, di), null);
		sort!("a.size > b.size")(subs);
		return new Box(di, subs);
	} else {
		return new Box(di, null);
	}
}

void Layout(Box[] boxes, double x0, double y0, double width, double height)
{
	if (boxes is null) return;
	switch(boxes.length) {
		case 0: break;
		case 1: boxes[0].place(x0,y0, width, height); break;
		case 2:
			double k = (cast(double) boxes[0].size) / (boxes[0].size + boxes[1].size);
			if (width > height) {
				boxes[0].place(x0, y0,           width*k, height);
				boxes[1].place(x0 + width*k, y0, width*(1-k), height);
			} else {
				boxes[0].place(x0, y0,            width, height*k);
				boxes[1].place(x0, y0 + height*k, width, height*(1-k));
			}
			break;
		default:
			double total = boxes.map!(b => b.size).sum;
			int i = 0;
			double x = x0;
			while(i < boxes.length) {
				double w = width * (boxes[i].size / total);
				if (w > height / 2.0) { //fat enough
					boxes[i].place(x, y0, w, height);
					x += w;
					i++;
				} else { //only thin ones left
					if (boxes.length - i <= 2) // just 1 or 2 left
						Layout(boxes[i..$], x, y0, width - (x-x0), height);
					else {
						long ttl = boxes[i..$].map!(b => b.size).sum;
						long half =  ttl / 2;
						long s = 0, bestd = half * 2 + 100;
						int bestk = i;
						foreach(j; i..boxes.length) {
							long dist = abs(half - s);
							if (dist < bestd) {
								bestk = j;	bestd = dist;
							} else break;
							s += boxes[j].size;
						}
						auto left = boxes[i..bestk], right = boxes[bestk..$];
						double leftsz = left.map!(b => b.size).sum;
						double kh = leftsz / ttl;
						double wd = width - (x-x0);
						Layout(left,  x, y0,               wd, height * kh);
						Layout(right, x, y0 + height * kh, wd, height * (1-kh));
					}
					break;
				}//if fat or thing
			} //while i < length
	}//switch boxes.length
}

struct Set(T)
{
	bool[T] data;

	void add(T x) { data[x] = true; }
	void addMany(R)(R rng) { foreach(x; rng) data[x] = true; }
	auto elems() { return data.byKey(); }
	@property int length() { return data.length; }
}

Set!T mkSet(T, R)(R xs)
{
	Set!T s;
	s.addMany(xs);
	return s;
}

alias SimilarDirs = Similar!(Set!int, IFSObject);
alias SimilarBoxes = Similar!(Tuple!(Box[], IFSObject[]), IFSObject);
alias SimilarFiles = Similar!(Set!string, IFSObject);

SimilarBoxes simBoxesOfSets(T)(Similar!(Set!T, IFSObject) s, Box[T] boxIndex, IFSObject[T] t2ifs)
{
	auto f(Set!T set) {
		auto boxes = set.data.keys.map!(id => boxIndex.get(id,null)).filter!(p => p !is null).array;
		auto ifs   = set.data.keys.map!(id => t2ifs.get(id,null)).array;
		return tuple(boxes, ifs);
	}
	return s.fmap!(Tuple!(Box[], IFSObject[]), IFSObject)(&f);
}
