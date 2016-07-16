Introduction
====================

BSKeyboardControls makes it easy to add an input accessory view above the keyboard which allows to go to the previous and next text fields as well as close the keyboard. Much like it is seen in Safari on iOS.

- iPhone and iPad compatible
- Requires iOS 5+
- Uses ARC

Installation
====================

The easiest way to use BSKeyboardControls is to copy the files in `BSKeyboardControls/` into your Xcode project.

1. In Finder, navigate to your `BSKeyboardControls` directory
2. Drag the complete directory into Xcode

Usage
====================

Wherever you want to use BSKeyboardControls import `BSKeyboardControls.h` like this:

`#import "BSKeyboardControls.h"`

Now you will have to set up BSKeyboardControls. This is done in five easy steps:

1. Initialize the keyboard controls
2. Set the delegate of the keyboard controls
3. Add all the fields to the keyboard controls (The order of the fields is important)
5. Set the delegate of all the text fields

Below is an example on how to setup the keyboard controls. The below example assumes the the text fields and the text views have had their delegate set in Interface Builder.

	NSArray *fields = @[ self.textFieldUsername, self.textFieldPassword,
                         self.textFieldRepeatedPassword, self.textViewAbout,
                         self.textFieldFavoriteFood, self.textFieldFavoriteMovie,
                         self.textFieldFavoriteBook, self.textViewNotes];
    
    [self setKeyboardControls:[[BSKeyboardControls alloc] initWithFields:fields]];
    [self.keyboardControls setDelegate:self];
	
Next you will have to set up the delegation methods. BSKeyboardControls requires three delegates: `BSKeyboardControlsDelegate`, `UITextFieldDelegate` and `UITextViewDelegate`.

First you want to close the keyboard if the user presses the "Done button".

	- (void)keyboardControlsDonePressed:(BSKeyboardControls *)keyboardControls
	{
    	[keyboardControls.activeField resignFirstResponder];
	}
	
Next you want the view to scroll whenever a field is selected. There are a lot of ways to do this and you may have to tweak this.

	- (void)keyboardControls:(BSKeyboardControls *)keyboardControls selectedField:(UIView *)field inDirection:(BSKeyboardControlsDirection)direction
	{
    	UIView *view = keyboardControls.activeField.superview.superview;
	    [self.tableView scrollRectToVisible:view.frame animated:YES];
	}
	
This is all there is for the `BSKeyboardControlsDelegate`. Now you want to set up the `UITextFieldDelegate`. The only method required is `- (void)textFieldDidBeginEditing:`

	- (void)textFieldDidBeginEditing:(UITextField *)textField
	{
    	[self.keyboardControls setActiveField:textField];
	}
	
Next you set up the `- (void)textViewDidBeginEditing:` method of the `UITextViewDelegate`. This is similar to the `UITextFieldDelegate`.

	- (void)textViewDidBeginEditing:(UITextView *)textView
	{
    	[self.keyboardControls setActiveField:textView];
	}
	
Now you are ready to use BSKeyboardControls. For more information on how to use BSKeyboardControls, please see `Example.xcodeproj`.