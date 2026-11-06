using System;
using System.IO;
using System.Text;
using System.Drawing;
using System.Diagnostics;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace CampusToggle {
  internal sealed class Entry {
    public readonly string Name, Book;
    public string Display;
    public Entry(string name, string book) { Name=name; Book=book; Display=name; }
    public override string ToString() { return Display; }
    public bool SameAs(Entry other) { return other != null && String.Equals(Name,other.Name,StringComparison.OrdinalIgnoreCase) && String.Equals(Book,other.Book,StringComparison.OrdinalIgnoreCase); }
    public bool IsValid() { return ValidPart(Name) && ValidPart(Book); }
    private static bool ValidPart(string value) { return !String.IsNullOrWhiteSpace(value) && value.IndexOfAny(new char[]{'"','\r','\n','\0'}) < 0; }
  }
  internal static class SelectionStore {
    public static Entry Load(string path) {
      if (!File.Exists(path)) return null;
      string[] lines = File.ReadAllLines(path,Encoding.Unicode);
      if (lines.Length < 2) throw new InvalidDataException("保存的连接信息不完整。");
      Entry entry = new Entry(lines[0],lines[1]);
      if (!entry.IsValid()) throw new InvalidDataException("保存的连接信息无效。");
      return entry;
    }
    public static void Save(string path, Entry entry) {
      if (entry == null || !entry.IsValid()) throw new InvalidDataException("连接名称或配置路径无效。");
      Directory.CreateDirectory(Path.GetDirectoryName(path));
      string temp=path+"."+Guid.NewGuid().ToString("N")+".tmp";
      try {
        using (var writer = new StreamWriter(temp,false,Encoding.Unicode)) { writer.WriteLine(entry.Name); writer.WriteLine(entry.Book); }
        if (File.Exists(path)) File.Replace(temp,path,null); else File.Move(temp,path);
      } finally { if (File.Exists(temp)) File.Delete(temp); }
    }
  }
  internal static class RasEntries {
    [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]
    private struct RasEntryName { public int Size; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=257)] public string Name; public int Flags; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=261)] public string Book; }
    [DllImport("rasapi32.dll",EntryPoint="RasEnumEntriesW",CharSet=CharSet.Unicode)]
    private static extern int RasEnumEntries(string reserved,string phonebook,IntPtr entries,ref int bytes,out int count);
    public static List<Entry> Read() {
      int bytes=0, count=0; int error=RasEnumEntries(null,null,IntPtr.Zero,ref bytes,out count);
      if (error==0 && bytes==0) return new List<Entry>();
      if (error!=603 || bytes<=0) throw new InvalidOperationException("读取拨号连接失败，错误代码："+error);
      for (int attempt=0; attempt<3; attempt++) {
        IntPtr buffer=Marshal.AllocHGlobal(bytes);
        try {
          int size=Marshal.SizeOf(typeof(RasEntryName)); Marshal.WriteInt32(buffer,size);
          int used=bytes; error=RasEnumEntries(null,null,buffer,ref used,out count);
          if (error==603) { bytes=used; continue; }
          if (error!=0) throw new InvalidOperationException("读取拨号连接失败，错误代码："+error);
          List<Entry> result=new List<Entry>();
          for(int i=0;i<count;i++) {
            RasEntryName item=(RasEntryName)Marshal.PtrToStructure(IntPtr.Add(buffer,i*size),typeof(RasEntryName));
            Entry entry=new Entry(item.Name,item.Book); if (entry.IsValid()) result.Add(entry);
          }
          return result;
        } finally { Marshal.FreeHGlobal(buffer); }
      }
      throw new InvalidOperationException("拨号连接列表正在变化，请刷新后重试。");
    }
  }
  static class Program {
    [STAThread] static void Main() {
      Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
      string startup=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Startup),"Campus Network Auto Connect.vbs");
      string settings=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),"Codex","CampusNetworkSwitch","connection.txt");
      Application.Run(new Dashboard(startup,settings,RasEntries.Read));
    }
  }
  internal sealed class Dashboard : Form {
    readonly string enabledPath, settingsPath;
    readonly Func<List<Entry>> readEntries;
    string DisabledPath { get { return enabledPath+".disabled"; } }
    Label status, statusDesc, badge, chosen, notice;
    Button on, off, save, refresh, settings;
    ComboBox networks;
    NumericUpDown delaySeconds, maxAttempts, retrySeconds;
    Label delayNotice;
    Panel card;
    Entry saved;
    List<Entry> available=new List<Entry>();
    bool listAvailable, reloading;
    readonly Color dark=Color.FromArgb(25,39,57), muted=Color.FromArgb(102,119,134), green=Color.FromArgb(18,159,120), pale=Color.FromArgb(231,237,239), red=Color.FromArgb(172,70,69);
    public Dashboard(string startupPath,string selectionPath,Func<List<Entry>> listProvider) {
      enabledPath=startupPath; settingsPath=selectionPath; readEntries=listProvider;
      Text="校园网自动连接"; ClientSize=new Size(576,755); StartPosition=FormStartPosition.CenterScreen;
      FormBorderStyle=FormBorderStyle.FixedDialog; MaximizeBox=false; BackColor=Color.FromArgb(245,248,250);
      Font=new Font("Microsoft YaHei UI",9f); AutoScaleMode=AutoScaleMode.Font;
      try { Icon=Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
      LabelAt(this,"校园网自动连接",34,22,450,41,20f,FontStyle.Bold,dark);
      LabelAt(this,"开机拨号与连接设置",36,66,440,26,10f,FontStyle.Regular,muted);
      card=new Panel { Location=new Point(34,108),Size=new Size(507,177),BackColor=Color.White };
      card.Paint+=delegate(object sender,PaintEventArgs e) { using(Pen pen=new Pen(Color.FromArgb(229,235,239))) e.Graphics.DrawRectangle(pen,0,0,card.Width-1,card.Height-1); };
      badge=LabelAt(card,"●  开机自动连接",23,14,220,25,9f,FontStyle.Bold,green);
      status=LabelAt(card,"",23,42,460,36,18f,FontStyle.Bold,dark);
      statusDesc=LabelAt(card,"",25,79,454,25,9f,FontStyle.Regular,muted);
      on=ButtonAt(card,"开启",25,119,218,40,green,Color.White); on.Click+=delegate { SetState(true); };
      off=ButtonAt(card,"关闭",260,119,220,40,pale,dark); off.Click+=delegate { SetState(false); };
      Controls.Add(card);
      LabelAt(this,"拨号连接",35,302,350,30,12f,FontStyle.Bold,dark);
      networks=new ComboBox { Location=new Point(35,341),Size=new Size(299,34),DropDownStyle=ComboBoxStyle.DropDownList,Font=new Font("Microsoft YaHei UI",10f),FlatStyle=FlatStyle.Flat,MaxDropDownItems=10,DropDownWidth=450 };
      networks.SelectedIndexChanged+=delegate { if(!reloading) UpdateSelectionUI(); }; Controls.Add(networks);
      refresh=ButtonAt(this,"刷新",343,338,78,36,Color.FromArgb(234,239,242),dark); refresh.Click+=delegate { LoadData(); };
      save=ButtonAt(this,"保存连接",430,338,111,36,green,Color.White); save.Click+=delegate { SaveSelection(); };
      chosen=LabelAt(this,"",36,386,505,24,9f,FontStyle.Regular,muted); chosen.AutoEllipsis=true;
      notice=LabelAt(this,"",36,411,505,40,9f,FontStyle.Regular,muted);
      LabelAt(this,"拨号等待时间",35,462,130,30,11f,FontStyle.Bold,dark);
      delaySeconds=new NumericUpDown { Location=new Point(190,466),Size=new Size(76,30), Minimum=0, Maximum=300, Font=new Font("Microsoft YaHei UI",10f) };
      try { int seconds; string delayFile=Path.Combine(Path.GetDirectoryName(settingsPath),"delay.txt"); delaySeconds.Value=File.Exists(delayFile) && Int32.TryParse(File.ReadAllText(delayFile),out seconds) && seconds>=0 && seconds<=300 ? seconds : 3; } catch { delaySeconds.Value=3; }
      Controls.Add(delaySeconds);
      LabelAt(this,"秒（0–300）",276,466,130,28,9f,FontStyle.Regular,muted);
      Button saveDelay=ButtonAt(this,"保存设置",430,462,111,36,green,Color.White);
      LabelAt(this,"总拨号次数",35,508,128,28,10f,FontStyle.Bold,dark);
      maxAttempts=new NumericUpDown { Location=new Point(165,509),Size=new Size(65,30),Minimum=1,Maximum=10,Font=new Font("Microsoft YaHei UI",10f),Value=3 };
      Controls.Add(maxAttempts);
      LabelAt(this,"次",235,509,24,28,9f,FontStyle.Regular,muted);
      LabelAt(this,"重试间隔",265,508,96,28,10f,FontStyle.Bold,dark);
      retrySeconds=new NumericUpDown { Location=new Point(365,509),Size=new Size(65,30),Minimum=1,Maximum=300,Font=new Font("Microsoft YaHei UI",10f),Value=5 };
      Controls.Add(retrySeconds);
      LabelAt(this,"秒",438,509,35,28,9f,FontStyle.Regular,muted);
      try { string retryFile=Path.Combine(Path.GetDirectoryName(settingsPath),"retry.txt"); if(File.Exists(retryFile)) { string[] values=File.ReadAllText(retryFile).Split(','); int count, interval; if(values.Length==2 && Int32.TryParse(values[0],out count) && Int32.TryParse(values[1],out interval) && count>=1 && count<=10 && interval>=1 && interval<=300) { maxAttempts.Value=count; retrySeconds.Value=interval; } } } catch { }
      delayNotice=LabelAt(this,"",36,549,505,22,8.5f,FontStyle.Regular,muted);
      saveDelay.Click+=delegate { try { string delayFile=Path.Combine(Path.GetDirectoryName(settingsPath),"delay.txt"); Directory.CreateDirectory(Path.GetDirectoryName(delayFile)); File.WriteAllText(delayFile,((int)delaySeconds.Value).ToString(),Encoding.ASCII); string retryFile=Path.Combine(Path.GetDirectoryName(settingsPath),"retry.txt"); File.WriteAllText(retryFile,((int)maxAttempts.Value).ToString()+","+((int)retrySeconds.Value).ToString(),Encoding.ASCII); delayNotice.Text="拨号设置已保存，下次登录时生效。"; delayNotice.ForeColor=green; } catch(Exception ex) { MessageBox.Show("无法保存拨号设置：\n"+ex.Message,Text,MessageBoxButtons.OK,MessageBoxIcon.Warning); } };
      LabelAt(this,"账号与密码",35,591,350,29,12f,FontStyle.Bold,dark);
      LabelAt(this,"通过 Windows 更新并保存拨号账号和密码。\n此工具不会读取或保存你的密码。",36,623,505,44,9f,FontStyle.Regular,muted);
      settings=ButtonAt(this,"打开 Windows 拨号设置",35,679,506,42,Color.FromArgb(229,237,240),dark);
      settings.Click+=delegate { try { Process.Start(new ProcessStartInfo("ms-settings:network-dialup") { UseShellExecute=true }); } catch(Exception ex) { MessageBox.Show("无法打开 Windows 拨号设置：\n"+ex.Message,Text,MessageBoxButtons.OK,MessageBoxIcon.Warning); } };
      LabelAt(this,"总次数包括首次拨号；账号或密码错误不会重试",37,730,505,20,8.5f,FontStyle.Regular,muted);
      LoadData();
    }
    Label LabelAt(Control parent,string text,int x,int y,int w,int h,float size,FontStyle style,Color color) {
      Label label=new Label { Text=text,Location=new Point(x,y),Size=new Size(w,h),ForeColor=color,Font=new Font("Microsoft YaHei UI",size,style),AutoSize=false,TextAlign=ContentAlignment.MiddleLeft,BackColor=parent.BackColor };
      parent.Controls.Add(label); return label;
    }
    Button ButtonAt(Control parent,string text,int x,int y,int w,int h,Color background,Color foreground) {
      Button button=new Button { Text=text,Location=new Point(x,y),Size=new Size(w,h),BackColor=background,ForeColor=foreground,FlatStyle=FlatStyle.Flat,Cursor=Cursors.Hand,Font=new Font("Microsoft YaHei UI",9.5f,FontStyle.Bold),UseVisualStyleBackColor=false };
      button.FlatAppearance.BorderSize=0; parent.Controls.Add(button); return button;
    }
    void LoadData() {
      reloading=true; saved=null; listAvailable=false; available=new List<Entry>(); networks.Items.Clear();
      string error=null;
      try { saved=SelectionStore.Load(settingsPath); }
      catch(Exception ex) { error="读取已保存的连接失败："+ex.Message; }
      try {
        available=readEntries(); listAvailable=true;
        foreach(Entry entry in available) {
          int duplicates=0; foreach(Entry other in available) if(String.Equals(entry.Name,other.Name,StringComparison.OrdinalIgnoreCase)) duplicates++;
          entry.Display=duplicates>1 ? entry.Name+"  —  "+entry.Book : entry.Name;
          networks.Items.Add(entry);
          if(entry.SameAs(saved)) networks.SelectedItem=entry;
        }
      } catch(Exception ex) { listAvailable=false; error="读取拨号连接失败："+ex.Message; }
      reloading=false; UpdateState(); UpdateSelectionUI();
      if(error!=null) { notice.Text=error; notice.ForeColor=red; }
    }
    bool HasSavedEntry() { if(!listAvailable || saved==null) return false; foreach(Entry entry in available) if(entry.SameAs(saved)) return true; return false; }
    void UpdateState() {
      bool a=File.Exists(enabledPath), b=File.Exists(DisabledPath), exists=HasSavedEntry();
      if(a && !b) { status.Text="已开启"; badge.ForeColor=green; statusDesc.Text="登录 Windows 后将尝试自动拨号。"; on.Enabled=false; off.Enabled=true; }
      else if(!a && b) { status.Text="已关闭"; badge.ForeColor=muted; statusDesc.Text="登录 Windows 后不会自动拨号。"; on.Enabled=exists; off.Enabled=false; }
      else { status.Text="需要检查设置"; badge.ForeColor=red; statusDesc.Text=a ? "检测到重复的启动文件。" : "找不到启动文件。"; on.Enabled=false; off.Enabled=false; }
      on.BackColor=on.Enabled?green:pale; on.ForeColor=on.Enabled?Color.White:muted;
      off.BackColor=off.Enabled?Color.FromArgb(252,236,233):pale; off.ForeColor=off.Enabled?red:muted;
    }
    void UpdateSelectionUI() {
      Entry picked=networks.SelectedItem as Entry; bool exists=HasSavedEntry();
      networks.Enabled=listAvailable && networks.Items.Count>0; save.Enabled=picked!=null; save.BackColor=save.Enabled?green:pale; save.ForeColor=save.Enabled?Color.White:muted;
      chosen.Text=saved==null?"尚未保存拨号连接":"当前保存："+saved.Name;
      if(!listAvailable) { notice.Text="无法读取连接列表，请稍后刷新。"; notice.ForeColor=red; }
      else if(saved!=null && !exists) { notice.Text="已保存的连接不存在或已更名，请重新选择并保存。"; notice.ForeColor=red; }
      else if(available.Count==0) { notice.Text="没有找到拨号连接，请在 Windows 中添加后刷新。"; notice.ForeColor=muted; }
      else if(picked!=null && !picked.SameAs(saved)) { notice.Text="点击“保存连接”后，下次登录将使用所选连接。"; notice.ForeColor=green; }
      else { notice.Text="更换或重命名连接后，请重新选择并保存。"; notice.ForeColor=muted; }
    }
    void SaveSelection() {
      Entry picked=networks.SelectedItem as Entry; if(picked==null) return;
      try {
        bool exists=false; foreach(Entry entry in readEntries()) if(entry.SameAs(picked)) exists=true;
        if(!exists) { LoadData(); MessageBox.Show("此连接已不存在，请刷新列表后重新选择。",Text,MessageBoxButtons.OK,MessageBoxIcon.Information); return; }
        SelectionStore.Save(settingsPath,picked); saved=picked; UpdateState(); UpdateSelectionUI(); notice.Text="已保存连接，下次登录将使用此连接。"; notice.ForeColor=green;
      } catch(Exception ex) { MessageBox.Show("无法保存连接：\n"+ex.Message,Text,MessageBoxButtons.OK,MessageBoxIcon.Warning); }
    }
    void SetState(bool turnOn) {
      try {
        bool a=File.Exists(enabledPath), b=File.Exists(DisabledPath);
        if(turnOn && !a && b && HasSavedEntry()) File.Move(DisabledPath,enabledPath);
        else if(!turnOn && a && !b) File.Move(enabledPath,DisabledPath);
        UpdateState();
      } catch(Exception ex) { MessageBox.Show("无法修改自动连接设置：\n"+ex.Message,Text,MessageBoxButtons.OK,MessageBoxIcon.Warning); UpdateState(); }
    }
  }
}