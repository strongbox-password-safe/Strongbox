# Disabling AutoFill Suggestion for an Entry
This is a simple way for a user to specify that they don't want a particular entry "Suggested" to them in AutoFill, for example in the Dropdown suggestions menu in the browser. 

To do this Strongbox uses a CustomData key/value pair like this:

`"KPEX_DoNotSuggestForAutoFill" = "True"`

Where the value is the standard KeePass boolean string "True". Here is what the KeePass XML entry looks like:

```
<Entry>
	<UUID>3m+H+PlcSASzTVYaDNFyVA==</UUID>
	<String>
		<Key>Title</Key>
		<Value>My Entry</Value>
	</String>
	<String>
		<Key>UserName</Key>
		<Value>user</Value>
	</String>
	<String>
		<Key>Password</Key>
		<Value Protected="True" />
	</String>
	<Times>
		<LastModificationTime>p4JE3A4AAAA=</LastModificationTime>
		<CreationTime>nYJE3A4AAAA=</CreationTime>
		<LastAccessTime>p4JE3A4AAAA=</LastAccessTime>
		<Expires>False</Expires>
		<UsageCount>2</UsageCount>
		<LocationChanged>nYJE3A4AAAA=</LocationChanged>
	</Times>
	<CustomData>
		<Item>
			<Key>KPEX_DoNotSuggestForAutoFill</Key>
			<Value>True</Value>
			<LastModificationTime>p4JE3A4AAAA=</LastModificationTime>
		</Item>
	</CustomData>
</Entry>
```
