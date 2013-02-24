module visual;
import dfl.all, fileops, std.range, std.algorithm, std.stdio, std.math, std.c.windows.windows, dfl.internal.winapi,
	std.string;
immutable small_size = 4_000_000;

string sizeString(long sz)
{
	enum long MB = 1024*1024; 
	if (sz >= MB) return format("%s MB", sz / MB);
	return format("%s bytes", sz);
}

class Dummy : IFSObject {
	long sz;
	DirInfo parent;

	string fullName() const { return parent is null ? "..." : parent.fullName() ~ "/..."; }	
	long getSize() { return sz; }

	this(long _size, DirInfo _parent) { sz = _size; parent = _parent; }
}

class Box {
	IFSObject item;
	double x,y, w,h;
	Box[] subs;

	this(IFSObject fsobject, Box[] _subs)
	{
		item = fsobject; subs = _subs;
	}

	@property size() { return item.getSize(); }

	void place(double x0, double y0, double width, double height)
	{
		x = x0; y = y0; w = width; h = height;
		if (subs !is null) Layout(subs, x0, y0, width, height);
	}

	void draw(void delegate(double x, double y, double w, double h) drawrect)
	{
		if (subs is null || subs.length==0) 
			drawrect(x,y,w,h);
		else
			foreach(bx; subs)
				bx.draw(drawrect);
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

class MyPictureBox : PictureBox {
	this() 
	{
		super();
		setStyle(ControlStyles.OPAQUE, true);
	}
}

class Visual : dfl.form.Form
{
	Box[] top;
	MyPictureBox picBox;
	dfl.label.Label lblFile;
	Rect[] volumeRects;
	Rect resParentRect;

	this(Box[] _top) {
		top = _top;

		initializeVisual();
	}

	void initializeVisual()
	{
		text = "Visual search";
		clientSize = dfl.all.Size(1040, 740);

		picBox = new MyPictureBox();
		picBox.name = "picBox";
		picBox.sizeMode = dfl.all.PictureBoxSizeMode.NORMAL;
		picBox.bounds = dfl.all.Rect(0, 0, 1000, 700);
		picBox.parent = this;
		

		lblFile = new dfl.label.Label();
		lblFile.name = "lblFile";
		lblFile.text = "---";
		lblFile.textAlign = dfl.all.ContentAlignment.MIDDLE_LEFT;
		lblFile.bounds = dfl.all.Rect(0, 700, 1000, 24);
		lblFile.parent = this;

		picBox.mouseMove ~= &OnMouseMove;
		picBox.paint ~= &OnPicPaint;

		displayBoxes();
	}

	void displayBoxes()
	{
		int w = 1000, h = 700;
		Layout(top, 0.0,0.0,w,h);

		HBITMAP hbm = CreateCompatibleBitmap(Graphics.getScreen().handle, w, h);
		int[] data;
		data.length = w*h;

		void drawBar(double x0, double y0, double dx, double dy)
		{
			int iy0 = cast(int)y0, ix0 = cast(int)x0, ix1 = cast(int) (x0 + dx), iy1 = cast(int) (y0+dy);
			if (ix1 >= w) ix1 = w;
			if (iy1 >= h) iy1 = h;
			foreach(iy; iy0 .. iy1) {
				real ky = sin(3 * cast(real)(iy - iy0) / dy);
				int di = iy * w + ix0;
				foreach(ix; ix0 .. ix1) {
					real kx = sin(3 * cast(real)(ix - ix0) / dx);
					int c = cast(int)(kx * ky * 200) + 50;
					data[di++] = (c << 16) | (c << 8) | c;
				}
			}
		}

		foreach(bx; top)
			bx.draw(&drawBar);

		SetBitmapBits(hbm, data.length*4, data.ptr);
		delete data;		

		volumeRects = top.map!(bx => bx.rect).array;
		picBox.image = new Bitmap(hbm, true);
	}

	void OnMouseMove(Control c, MouseEventArgs ma)
	{
		if (ma.x < 1000 && ma.y < 700) {
			Box resParent;
			auto bxs = top.map!(b => b.findByPoint(ma.x, ma.y, null, resParent)).find!"a !is null";
			if (!bxs.empty) {
				lblFile.text = format("%s (%s, parent: %s)", bxs[0].item.fullName(), bxs[0].item.getSize.sizeString,
									  resParent is null ? "-" : resParent.item.getSize.sizeString);
				if (resParent !is null) { 
					resParentRect = resParent.rect;
					picBox.invalidate();
				}
			}
		}
	}

	void OnPicPaint(Control c, PaintEventArgs pa)
	{
		scope Pen p = new Pen(Color.fromRgb(0xFF));
		foreach(rc; volumeRects) 
			pa.graphics.drawRectangle(p, rc);
		scope Pen yellow = new Pen(Color.fromRgb(0xFFFF));
		pa.graphics.drawRectangle(yellow, resParentRect);
	}

}//class Visual

void vsearch(string fname)
{
	writeln("reading ", fname);
	DirInfo[] dirs = useIndex(readDump(fname));
	writeln("getting top");
	DirInfo[] topdirs = dirs.filter!(di => di.parent is null).array;
	writeln("making box tree");
	Box[] top = topdirs.map!(boxOfDir).array;
	try
	{
		Application.enableVisualStyles();
		//@  Other application initialization code here.
		Application.run(new Visual(top));
	}
	catch(Throwable o)
	{
		msgBox(o.toString(), "Fatal Error", MsgBoxButtons.OK, MsgBoxIcon.ERROR);		
	}
}