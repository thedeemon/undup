import dfl.all, core.sys.windows.windows, std.utf, std.conv, std.stdio, std.datetime, std.concurrency, fileops;

struct DumpHeader {
	string path, name, volume;
	int volumeSize;
	long time;
}

class NewScan: dfl.form.Form
{
	// Do not modify or move this block of variables.
	//~Entice Designer variables begin here.
	dfl.textbox.TextBox tbxPath;
	dfl.label.Label label2;
	dfl.button.Button btnBrowse;
	dfl.textbox.TextBox tbxName;
	dfl.label.Label label3;
	dfl.label.Label label4;
	dfl.textbox.TextBox tbxVolume;
	dfl.label.Label label5;
	dfl.textbox.TextBox tbxVolumeSize;
	dfl.label.Label label6;
	dfl.textbox.TextBox tbxTime;
	dfl.button.Button btnStart;
	dfl.progressbar.ProgressBar progressBar1;
	dfl.label.Label lblStatus;
	dfl.button.Button btnCancel;
	//~Entice Designer variables end here.
	
	long timeStamp, volumeSize;
	
	this()
	{
		initializeNewScan();
		
		//@  Other NewScan initialization code here.
		
	}
	
	
	private void initializeNewScan()
	{
		// Do not manually modify this function.
		//~Entice Designer 0.8.5.02 code begins here.
		//~DFL Form
		text = "New Scan";
		clientSize = dfl.all.Size(448, 242);
		//~DFL dfl.textbox.TextBox=tbxPath
		tbxPath = new dfl.textbox.TextBox();
		tbxPath.name = "tbxPath";
		tbxPath.readOnly = true;
		tbxPath.bounds = dfl.all.Rect(120, 16, 240, 24);
		tbxPath.parent = this;
		//~DFL dfl.label.Label=label2
		label2 = new dfl.label.Label();
		label2.name = "label2";
		label2.text = "Root path:";
		label2.textAlign = dfl.all.ContentAlignment.MIDDLE_RIGHT;
		label2.bounds = dfl.all.Rect(8, 16, 104, 24);
		label2.parent = this;
		//~DFL dfl.button.Button=btnBrowse
		btnBrowse = new dfl.button.Button();
		btnBrowse.name = "btnBrowse";
		btnBrowse.text = "Browse";
		btnBrowse.bounds = dfl.all.Rect(368, 16, 72, 24);
		btnBrowse.parent = this;
		//~DFL dfl.textbox.TextBox=tbxName
		tbxName = new dfl.textbox.TextBox();
		tbxName.name = "tbxName";
		tbxName.bounds = dfl.all.Rect(120, 48, 240, 24);
		tbxName.parent = this;
		//~DFL dfl.label.Label=label3
		label3 = new dfl.label.Label();
		label3.name = "label3";
		label3.text = "Name:";
		label3.textAlign = dfl.all.ContentAlignment.MIDDLE_RIGHT;
		label3.bounds = dfl.all.Rect(8, 48, 104, 24);
		label3.parent = this;
		//~DFL dfl.label.Label=label4
		label4 = new dfl.label.Label();
		label4.name = "label4";
		label4.text = "Volume name:";
		label4.textAlign = dfl.all.ContentAlignment.MIDDLE_RIGHT;
		label4.bounds = dfl.all.Rect(8, 80, 104, 24);
		label4.parent = this;
		//~DFL dfl.textbox.TextBox=tbxVolume
		tbxVolume = new dfl.textbox.TextBox();
		tbxVolume.name = "tbxVolume";
		tbxVolume.readOnly = true;
		tbxVolume.bounds = dfl.all.Rect(120, 80, 240, 24);
		tbxVolume.parent = this;
		tbxVolume.enabled = false;
		//~DFL dfl.label.Label=label5
		label5 = new dfl.label.Label();
		label5.name = "label5";
		label5.text = "Volume size:";
		label5.textAlign = dfl.all.ContentAlignment.MIDDLE_RIGHT;
		label5.bounds = dfl.all.Rect(8, 112, 104, 24);
		label5.parent = this;
		//~DFL dfl.textbox.TextBox=tbxVolumeSize
		tbxVolumeSize = new dfl.textbox.TextBox();
		tbxVolumeSize.name = "tbxVolumeSize";
		tbxVolumeSize.readOnly = true;
		tbxVolumeSize.bounds = dfl.all.Rect(120, 112, 240, 24);
		tbxVolumeSize.parent = this;
		tbxVolumeSize.enabled = false;
		//~DFL dfl.label.Label=label6
		label6 = new dfl.label.Label();
		label6.name = "label6";
		label6.text = "Time:";
		label6.textAlign = dfl.all.ContentAlignment.MIDDLE_RIGHT;
		label6.bounds = dfl.all.Rect(8, 144, 104, 24);
		label6.parent = this;
		//~DFL dfl.textbox.TextBox=tbxTime
		tbxTime = new dfl.textbox.TextBox();
		tbxTime.name = "tbxTime";
		tbxTime.readOnly = true;
		tbxTime.bounds = dfl.all.Rect(120, 144, 240, 24);
		tbxTime.parent = this;
		tbxTime.enabled = false;
		//~DFL dfl.button.Button=btnStart
		btnStart = new dfl.button.Button();
		btnStart.name = "btnStart";
		btnStart.text = "Start scan";
		btnStart.bounds = dfl.all.Rect(368, 176, 72, 24);
		btnStart.parent = this;
		//~DFL dfl.progressbar.ProgressBar=progressBar1
		progressBar1 = new dfl.progressbar.ProgressBar();
		progressBar1.name = "progressBar1";
		progressBar1.bounds = dfl.all.Rect(8, 176, 352, 24);
		progressBar1.parent = this;
		//~DFL dfl.label.Label=lblStatus
		lblStatus = new dfl.label.Label();
		lblStatus.name = "lblStatus";
		lblStatus.bounds = dfl.all.Rect(8, 208, 352, 24);
		lblStatus.parent = this;
		//~DFL dfl.button.Button=btnCancel
		btnCancel = new dfl.button.Button();
		btnCancel.name = "btnCancel";
		btnCancel.text = "Cancel";
		btnCancel.bounds = dfl.all.Rect(368, 208, 72, 24);
		btnCancel.parent = this;
		//~Entice Designer 0.8.5.02 code ends here.

		btnBrowse.click ~= &OnBrowse;
		auto t = Clock.currTime();
		tbxTime.text = t.toSimpleString();
		timeStamp = t.stdTime;
		btnStart.click ~= &OnStart;
	}

	void OnBrowse(Control, EventArgs)
	{
		auto dlg = new FolderBrowserDialog();
		if (dlg.showDialog()!=DialogResult.OK) return;
		auto path = dlg.selectedPath;		
		tbxPath.text = path;
		uint dt;
		long size;
		auto label = GetVolumeInfo(path, dt, size);	
		tbxVolume.text = label;		
		volumeSize = size / 1000_000_000;
		string szs = volumeSize.to!string ~ "GB";
		if (dt==3)  //fixed disk
			tbxName.text = GetComputerName() ~ "_" ~ path[0] ~ "_" ~ szs;
		else
			tbxName.text = label ~ "_" ~ szs;
		tbxVolumeSize.text = szs;
	}

	void OnStart(Control, EventArgs)
	{
		auto hdr = DumpHeader(tbxPath.text, tbxName.text, tbxVolume.text, cast(int)volumeSize, timeStamp);
	}
} // class NewScan

extern(Windows) {
	BOOL GetVolumePathNameW(LPCWSTR, LPWSTR, DWORD);	
	BOOL GetVolumeInformationW(LPCWSTR, LPWSTR, DWORD, PDWORD, PDWORD, PDWORD, LPWSTR, DWORD);
	UINT GetDriveTypeW(LPCWSTR);
	BOOL GetDiskFreeSpaceW(LPCWSTR, PDWORD, PDWORD, PDWORD, PDWORD);
}
	
string GetVolumeInfo(string path, out uint driveType, out long size)
{
	auto root = new wchar[1024];
	if (GetVolumePathNameW(path.toUTF16z, root.ptr, 1000)==0) return "";
	auto lab = new wchar[1024];
	if (GetVolumeInformationW(root.ptr, lab.ptr, 1000, null, null, null, null, 0)==0) return "";
	driveType = GetDriveTypeW(root.ptr);	
	uint secPerCluster, bytesPerSec, freeCl, totalCl;
	if (GetDiskFreeSpaceW(root.ptr, &secPerCluster, &bytesPerSec, &freeCl, &totalCl) != 0) 
		size = totalCl * cast(long)secPerCluster * bytesPerSec;
	return fromWStringz!(string)(lab.ptr);
}

string GetComputerName()
{
	auto name = new wchar[1024];
	uint sz = 1000;
	if (GetComputerNameW(name.ptr, &sz)==0) return "";
	return to!string(name[0..sz]);
}

auto toUTF16z(S)(S s)
{
    return toUTFz!(const(wchar)*)(s);
}

S fromWStringz(S)(const wchar* s)
{
    if (s is null) return null;
    wchar* ptr;
    for (ptr = cast(wchar*)s; *ptr; ++ptr) {}
    return to!S(s[0..ptr-s]);
}