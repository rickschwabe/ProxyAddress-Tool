#=======================================================================#
#																		#
# Tool Name	: ProxyAddress-Tool											#	
# Author 	: Rick Schwabe												#	
# Website	: http://www.itsystemengineer.com/ 							#	
# Github	: https://github.com/rickschwabe 							#
# LinkedIn  : https://de.linkedin.com/in/rick-schwabe-8a3a4b17a			#
#																		#
#=======================================================================#
$currentScriptDirectory = Get-Location
[System.IO.Directory]::SetCurrentDirectory($currentScriptDirectory.Path)

[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')  				| out-null
[System.Reflection.Assembly]::LoadWithPartialName('presentationframework') 				| out-null
[System.Reflection.Assembly]::LoadFrom('MahApps.Metro.dll')       						| out-null
[System.Reflection.Assembly]::LoadFrom('MahApps.Metro.IconPacks.dll')      				| out-null  
[System.Reflection.Assembly]::LoadFrom('CubicOrange.Windows.Forms.ActiveDirectory.dll') | out-null  

#===== LoadXml function =====#

function LoadXml ($global:filename)
{
    $XamlLoader=(New-Object System.Xml.XmlDocument)
    $XamlLoader.Load($filename)
    return $XamlLoader
}

# Load MainWindow from XAML
$XamlMainWindow=LoadXml("mainwindow.xaml")
$Reader=(New-Object System.Xml.XmlNodeReader $XamlMainWindow)
$Form=[Windows.Markup.XamlReader]::Load($Reader)

[System.Windows.Forms.Application]::EnableVisualStyles()

### bind MainWindow controls 
$browse_user = $Form.findname("browse_user") 
$textbox_user = $Form.findname("textbox_user") 
$textbox_smtp = $Form.findname("textbox_smtp")
$Change_Theme = $Form.findname("Change_Theme") 
$button_ok = $Form.findname("button_ok") 
$button_add = $Form.findname("button_add") 
$button_delete = $Form.findname("button_delete") 
$listbox_proxy = $Form.findname("listbox_proxy")

$Global:Current_Folder =(get-location).path 

#===== functions =====#

### function to reset gui controls to start ###
function set-default {
    $button_ok.IsEnabled = $false
    $textbox_user.Text = $null
    $textbox_user.IsEnabled = $false
    $textbox_smtp.Text = $null
    $textbox_smtp.IsEnabled = $false
    $button_delete.IsEnabled = $false
    $button_add.IsEnabled = $false
    $listbox_proxy.Items.Clear()
}

### function checks all required dependencies ###
function check-admodule {
	if (Get-Module -ListAvailable -Name ActiveDirectory) {
    	continue
	} 
	else {
		[MahApps.Metro.Controls.Dialogs.DialogManager]::ShowMessageAsync($Form, "Whoops " + [char]::ConvertFromUtf32(0x1F615), "Powershell Module 'ActiveDirectory' is missing!")
	}
}

### function to read the value of AD proxyaddresses attribut
function read-smtp ($samAccountName) {
	$listbox_proxy.Items.Clear()
	try{
		$addresses = Get-ADUser -Identity $samAccountName -Properties proxyaddresses
		foreach ($address in $addresses.proxyaddresses){
			$listbox_proxy.Items.Add($address)
		}
	}
	catch{
		[MahApps.Metro.Controls.Dialogs.DialogManager]::ShowMessageAsync($Form, "Whoops " + [char]::ConvertFromUtf32(0x1F609), "Error, users SMTP addresses can not be read!")
	}
	$button_add.IsEnabled = $true
	$button_delete.IsEnabled = $true
	$textbox_smtp.IsEnabled = $true
    $button_ok.IsEnabled = $true
}

### function to write into users AD proxyaddresses attribut
function set-smtp ($address) {
	try{
		Set-ADUser $textbox_user.Text -add @{ProxyAddresses="$address"}
		$textbox_smtp.Text = $null
		$listbox_proxy.Items.Clear()
		read-smtp -samAccountName $textbox_user.Text
	}
	catch{
		[MahApps.Metro.Controls.Dialogs.DialogManager]::ShowMessageAsync($Form, "Whoops " + [char]::ConvertFromUtf32(0x1F609), "Error, can not set SMTP value!")
	}
}

### function to remove a single smtp address ###
function remove-smtp ($address){
	try{
		Set-ADUser $textbox_user.Text -remove @{ProxyAddresses="$address"}
		$listbox_proxy.Items.Clear()
		read-smtp -samAccountName $textbox_user.Text
	}
	catch{
		[MahApps.Metro.Controls.Dialogs.DialogManager]::ShowMessageAsync($Form, "Whoops " + [char]::ConvertFromUtf32(0x1F609), "Error, can not remove SMTP value!")
	}
}

#===== button clicks =====#

### Change main window theme ###
$Change_Theme.Add_Click({
	$Theme = [MahApps.Metro.ThemeManager]::DetectAppStyle($form)	
	$Script:my_theme = ($Theme.Item1).name	
	If($my_theme -eq "BaseLight")
		{		
			[MahApps.Metro.ThemeManager]::ChangeAppStyle($form, $Theme.Item2, [MahApps.Metro.ThemeManager]::GetAppTheme("BaseDark"));			
		}
	ElseIf($my_theme -eq "BaseDark")
		{							
			[MahApps.Metro.ThemeManager]::ChangeAppStyle($form, $Theme.Item2, [MahApps.Metro.ThemeManager]::GetAppTheme("BaseLight"));			
		}		
})		
		
### Button for AD GUI to choose User ###
$browse_user.Add_Click({
	check-admodule		
	$DialogAD = New-Object CubicOrange.Windows.Forms.ActiveDirectory.DirectoryObjectPickerDialog
    
    $DialogAD.AllowedLocations = [CubicOrange.Windows.Forms.ActiveDirectory.Locations]::All
    $DialogAD.AllowedObjectTypes = [CubicOrange.Windows.Forms.ActiveDirectory.ObjectTypes]::Users
    $DialogAD.DefaultLocations = [CubicOrange.Windows.Forms.ActiveDirectory.Locations]::JoinedDomain
    $DialogAD.DefaultObjectTypes = [CubicOrange.Windows.Forms.ActiveDirectory.ObjectTypes]::Users
    $DialogAD.ShowAdvancedView = $false
    $DialogAD.MultiSelect = $false
    $DialogAD.SkipDomainControllerCheck = $false
    $DialogAD.Providers = [CubicOrange.Windows.Forms.ActiveDirectory.ADsPathsProviders]::Default
    
    $DialogAD.AttributesToFetch.Add('samAccountName')
    $DialogAD.AttributesToFetch.Add('distinguishedName')
    
    $DialogAD.ShowDialog()

    $textbox_user.Text = $DialogAD.Selectedobject.FetchedAttributes[0]
	read-smtp -samAccountName $DialogAD.Selectedobject.FetchedAttributes[0]
})	

### button event to call set-smtp function and check value ###
$button_add.Add_Click({
	if(($textbox_smtp.Text -like "smtp:*") -or ($textbox_smtp.Text -like "SMTP:*") -and ($textbox_smtp.Text -like "*@*")){
		set-smtp -address $textbox_smtp.Text
	}
	else{
		[MahApps.Metro.Controls.Dialogs.DialogManager]::ShowMessageAsync($Form, "Whoops " + [char]::ConvertFromUtf32(0x1F609), "'SMTP / smtp' is missing or the entry is not an email format!")
	}
})

### button event to call remove-smtp function ###
$button_delete.Add_Click({
	remove-smtp -address $listbox_proxy.SelectedItems
})

### button to reset gui or edit next user via set-default function ###
$button_ok.Add_Click({	
    set-default
})

set-default

$Form.ShowDialog() | Out-Null