using System;
using System.IO;
using System.Text;
using System.Runtime.InteropServices;
class Dialer {
 [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct Params {
  public int size;
  [MarshalAs(UnmanagedType.ByValTStr,SizeConst=257)] public string entry;
  [MarshalAs(UnmanagedType.ByValTStr,SizeConst=129)] public string phone;
  [MarshalAs(UnmanagedType.ByValTStr,SizeConst=129)] public string callback;
  [MarshalAs(UnmanagedType.ByValTStr,SizeConst=257)] public string user;
  [MarshalAs(UnmanagedType.ByValTStr,SizeConst=257)] public string password;
  [MarshalAs(UnmanagedType.ByValTStr,SizeConst=16)] public string domain;
  public int subEntry; public UIntPtr callbackId; public int ifIndex;
 }
 [DllImport("rasapi32.dll",EntryPoint="RasGetEntryDialParamsW",CharSet=CharSet.Unicode)] static extern int GetParams(string book,ref Params p,[MarshalAs(UnmanagedType.Bool)] out bool saved);
 [DllImport("rasapi32.dll",EntryPoint="RasDialW",CharSet=CharSet.Unicode)] static extern int Dial(IntPtr extensions,string book,ref Params p,int notifierType,IntPtr notifier,ref IntPtr connection);
 [DllImport("rasapi32.dll",EntryPoint="RasHangUpW")] static extern int HangUp(IntPtr connection);
 static int Main(string[] args) {
  try {
   string path=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),"Codex","CampusNetworkSwitch","connection.txt");
   string[] lines=File.ReadAllLines(path,Encoding.Unicode); if(lines.Length<2) return 2;
   Params p=new Params(); p.size=Marshal.SizeOf(typeof(Params)); p.entry=lines[0]; bool saved;
   int err=GetParams(lines[1],ref p,out saved); if(err!=0) return 3;
   if(!saved || String.IsNullOrEmpty(p.user)) return 4;
   if(args.Length>0 && args[0]=="--check") return 0;
   IntPtr connection=IntPtr.Zero; err=Dial(IntPtr.Zero,lines[1],ref p,0,IntPtr.Zero,ref connection);
   if(err!=0 && connection!=IntPtr.Zero) HangUp(connection); return err;
  } catch {return 6;}
 }
}
