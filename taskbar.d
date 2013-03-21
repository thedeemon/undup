module taskbar;
import core.sys.windows.windows, std.c.windows.com, std.stdio;

class TaskBarProgress
{
	this(HWND _hwnd)
	{
		hwnd = _hwnd;
	}

	@property void enabled(bool enable)
	{
		if (itl is null) {
			if (enable) {
				auto CLSID_TaskbarList = GUID(0x56FDF344, 0xFD6D, 0x11D0, [0x95, 0x8A, 0x00, 0x60, 0x97, 0xC9, 0xA0, 0x90]);
				auto IID_ITaskbarList3 = GUID(0xea1afb91, 0x9e28, 0x4b86, [0x90, 0xe9, 0x9e, 0x9f, 0x8a, 0x5e, 0xef, 0xaf]);
				CoCreateInstance(&CLSID_TaskbarList, null, CLSCTX_ALL, &IID_ITaskbarList3,  cast(void**)&itl);
			}
		} 
		if (itl !is null)
			itl.SetProgressState(hwnd, enable ? TBPFLAG.TBPF_NORMAL : TBPFLAG.TBPF_NOPROGRESS);
	}

	void SetValue(ulong cur, ulong total)
	{
		if (itl is null) return;
		itl.SetProgressValue(hwnd, cur, total);
	}

	void Clear()
	{
		if (itl is null) return;
		itl.Release();
		itl = null;
	}

	ITaskbarList3 itl;
	HWND hwnd;
}

extern(Windows) {
	interface ITaskbarList :  IUnknown
	{
		HRESULT  HrInit() ;
		HRESULT  AddTab(HWND hwnd) ;
		HRESULT  DeleteTab( HWND hwnd) ;
		HRESULT  ActivateTab(  HWND hwnd) ;
		HRESULT  SetActiveAlt( HWND hwnd) ;
	}

	interface ITaskbarList2 : ITaskbarList
	{
		HRESULT MarkFullscreenWindow(HWND hwnd, BOOL fFullscreen);
	}

	enum TBPFLAG  {	
		TBPF_NOPROGRESS	= 0,
		TBPF_INDETERMINATE	= 0x1,
		TBPF_NORMAL	= 0x2,
		TBPF_ERROR	= 0x4,
		TBPF_PAUSED	= 0x8
    }

	alias LPTHUMBBUTTON = void*; //I'm too lazy to translate these properly
	alias HIMAGELIST = void*;

	interface ITaskbarList3 : ITaskbarList2
	{

		HRESULT SetProgressValue(HWND hwnd, ULONGLONG ullCompleted, ULONGLONG ullTotal);
		HRESULT SetProgressState(HWND hwnd, TBPFLAG tbpFlags);
		HRESULT RegisterTab(HWND hwndTab, HWND hwndMDI);
		HRESULT UnregisterTab(HWND hwndTab);
		HRESULT SetTabOrder(HWND hwndTab, HWND hwndInsertBefore);
		HRESULT SetTabActive(HWND hwndTab, HWND hwndMDI, DWORD dwReserved);
		HRESULT ThumbBarAddButtons(HWND hwnd, UINT cButtons, LPTHUMBBUTTON pButton);
		HRESULT ThumbBarUpdateButtons(HWND hwnd, UINT cButtons, LPTHUMBBUTTON pButton);
		HRESULT ThumbBarSetImageList(HWND hwnd, HIMAGELIST himl);
		HRESULT SetOverlayIcon(HWND hwnd, HICON hIcon, LPCWSTR pszDescription);
		HRESULT SetThumbnailTooltip(HWND hwnd, LPCWSTR pszTip);
		HRESULT SetThumbnailClip(HWND hwnd, RECT *prcClip);
	}
}