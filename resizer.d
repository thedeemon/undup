module resizer;
import dfl.all, std.typecons, std.algorithm, std.array, std.range;

class Resizer 
{
	Form form;
	Size initialFormSize;
	ResizeRule[] rules;
	ResizeAction[] actions;

	this(Form f) {
		form = f;
		initialFormSize = f.clientSize;
	}

	void let(Control ctrl, Rule!(Coord.X) xrule, Rule!(Coord.Y) yrule)
	{
		if (ctrl is null) return;
		rules ~= new ResizeRule(ctrl, xrule, yrule, this);
	}

	void prepare()
	{
		actions = rules.map!(r => new ResizeAction(r)).array;
	}

	void go()
	{
		Size fsize = form.clientSize;
		foreach(a; actions)
			a.go(fsize);
	}
}

class ResizeRule
{
	Rect initialBounds;
	Control ctrl;
	Rule!(Coord.X) Xrule;
	Rule!(Coord.Y) Yrule;
	Size initialFormSize;

	this(Control c, Rule!(Coord.X) xrule, Rule!(Coord.Y) yrule, Resizer resizer)
	{
		ctrl = c;
		initialBounds = c.bounds;
		Xrule = xrule; Yrule = yrule;
		initialFormSize = resizer.initialFormSize;
	}
}

enum Coord { X, Y }
enum Action { Stay, Move, Resize, ScalePos, Scale }

struct Rule(Coord C)
{
	Action action;
}

class SetCoord(Coord C) {
	static Rule!(C) stays() { return Rule!(C)(Action.Stay); }
	static Rule!(C) moves() { return Rule!(C)(Action.Move); }
	static Rule!(C) resizes() { return Rule!(C)(Action.Resize); }
	static Rule!(C) scalesPos() { return Rule!(C)(Action.ScalePos); }
	static Rule!(C) scales() { return Rule!(C)(Action.Scale); }
}

alias XCoord = SetCoord!(Coord.X);
alias YCoord = SetCoord!(Coord.Y);

struct PosLen(Coord C) { int pos, len; }

int getVal(Coord C)(Size sz)
{
	static if (C==Coord.X) return sz.width;
	else return sz.height;
}

PosLen!(C) delegate(PosLen!(C), Size)  mkTrans(Coord C)(ResizeRule r, Rule!C rule)
{
	auto w0 = getVal!(C)(r.initialFormSize);
	final switch(rule.action) {
		case Action.Stay: return (PosLen!(C) pl, Size fsz) => pl; break;
		case Action.Move: return (PosLen!(C) pl, Size fsz) => PosLen!C(pl.pos + getVal!(C)(fsz) - w0, pl.len); break;
		case Action.Resize: return (PosLen!(C) pl, Size fsz) => PosLen!C(pl.pos, pl.len + getVal!(C)(fsz) - w0); break;
		case Action.ScalePos: 
			return (PosLen!(C) pl, Size fsz) => PosLen!C( pl.pos * getVal!(C)(fsz) / w0, pl.len); 
			break;
		case Action.Scale: 
			return (PosLen!(C) pl, Size fsz) => PosLen!C( pl.pos * getVal!(C)(fsz) / w0, pl.len * getVal!(C)(fsz) / w0); 
			break;
	}
}

PosLen!(C) toPosLen(Coord C)(Rect rc)
{
	static if (C==Coord.X) return PosLen!C(rc.x, rc.width);
	else return PosLen!C(rc.y, rc.height);
}

class ResizeAction
{
	Rect initialBounds;
	Control ctrl;
	PosLen!(Coord.X) delegate(PosLen!(Coord.X), Size form_size) fx;
	PosLen!(Coord.Y) delegate(PosLen!(Coord.Y), Size form_size) fy;

	this(ResizeRule r)
	{
		initialBounds = r.initialBounds;
		ctrl = r.ctrl;
		fx = mkTrans!(Coord.X)(r, r.Xrule);
		fy = mkTrans!(Coord.Y)(r, r.Yrule);
	}

	void go(Size fsize)
	{
		auto xs = fx(toPosLen!(Coord.X)(initialBounds), fsize);
		auto ys = fy(toPosLen!(Coord.Y)(initialBounds), fsize);
		ctrl.bounds = Rect(xs.pos, ys.pos, xs.len, ys.len);
	}
}