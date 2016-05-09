//
//  ApptentiveSurveyViewController.m
//  CVSurvey
//
//  Created by Frank Schmitt on 2/22/16.
//  Copyright © 2016 Apptentive, Inc. All rights reserved.
//

#import "ApptentiveSurveyViewController.h"
#import "ApptentiveSurveyViewModel.h"
#import "ApptentiveSurveyAnswerCell.h"
#import "ApptentiveSurveyChoiceCell.h"
#import "ApptentiveSurveyOtherCell.h"
#import "ApptentiveSurveySingleLineCell.h"
#import "ApptentiveSurveyMultilineCell.h"
#import "ApptentiveSurveyQuestionView.h"
#import "ApptentiveSurveyCollectionViewLayout.h"
#import "ApptentiveSurveyQuestionBackgroundView.h"
#import "ApptentiveSurveyOptionButton.h"
#import "ApptentiveSurveySubmitButton.h"
#import "ApptentiveSurveyGreetingView.h"

#import "ApptentiveBackend.h"
#import "ApptentiveHUDViewController.h"
#import "Apptentive_Private.h"

// These need to match the values from the storyboard
#define QUESTION_HORIZONTAL_MARGIN 52.0
#define QUESTION_VERTICAL_MARGIN 36.0

#define CHOICE_HORIZONTAL_MARGIN 70.0
#define CHOICE_VERTICAL_MARGIN 23.5

#define MULTILINE_HORIZONTAL_MARGIN 44
#define MULTILINE_VERTICAL_MARGIN 14


@interface ApptentiveSurveyViewController ()

@property (strong, nonatomic) IBOutlet ApptentiveSurveyGreetingView *headerView;
@property (strong, nonatomic) IBOutlet UIView *headerBackgroundView;
@property (strong, nonatomic) IBOutlet UIView *footerView;
@property (strong, nonatomic) IBOutlet UIView *footerBackgroundView;
@property (strong, nonatomic) IBOutlet ApptentiveSurveySubmitButton *submitButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *missingRequiredItem;

@property (strong, nonatomic) NSIndexPath *editingIndexPath;

@property (readonly, nonatomic) CGFloat lineHeightOfQuestionFont;

@end


@implementation ApptentiveSurveyViewController

- (void)viewDidLoad {
	[super viewDidLoad];

	self.collectionView.allowsMultipleSelection = YES;
	[self.collectionViewLayout registerClass:[ApptentiveSurveyQuestionBackgroundView class] forDecorationViewOfKind:@"QuestionBackground"];

	self.title = self.viewModel.title;

	self.headerView.greetingLabel.text = self.viewModel.greeting;
	[self.headerView.infoButton setImage:[ApptentiveBackend imageNamed:@"at_info"] forState:UIControlStateNormal];
	((ApptentiveSurveyCollectionView *)self.collectionView).collectionHeaderView = self.headerView;
	((ApptentiveSurveyCollectionView *)self.collectionView).collectionFooterView = self.footerView;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(adjustForKeyboard:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(adjustForKeyboard:) name:UIKeyboardWillHideNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sizeDidUpdate:) name:UIContentSizeCategoryDidChangeNotification object:nil];

	id<ApptentiveStyle> style = self.viewModel.styleSheet;

	self.collectionView.backgroundColor = [style colorForStyle:ApptentiveColorCollectionBackground];
	self.headerBackgroundView.backgroundColor = [style colorForStyle:ApptentiveColorHeaderBackground];
	self.headerView.greetingLabel.font = [style fontForStyle:ApptentiveTextStyleHeaderMessage];
	self.headerView.greetingLabel.textColor = [style colorForStyle:ApptentiveTextStyleHeaderMessage];
	self.headerView.infoButton.tintColor = [style colorForStyle:ApptentiveTextStyleSurveyInstructions];
	self.headerView.borderView.backgroundColor = [style colorForStyle:ApptentiveColorSeparator];

	self.footerBackgroundView.backgroundColor = [style colorForStyle:ApptentiveColorFooterBackground];
	self.submitButton.titleLabel.font = [style fontForStyle:ApptentiveTextStyleSubmitButton];
	self.submitButton.backgroundColor = [style colorForStyle:ApptentiveColorBackground];

	self.missingRequiredItem.tintColor = [style colorForStyle:ApptentiveColorBackground];
	self.missingRequiredItem.title = [self.viewModel missingRequiredItemText];

	self.toolbarItems = @[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
		self.missingRequiredItem,
		[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];

	self.navigationController.toolbar.translucent = NO;
	self.navigationController.toolbar.barTintColor = [style colorForStyle:ApptentiveColorFailure];
	self.navigationController.toolbar.userInteractionEnabled = NO;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
	[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
	[self.collectionViewLayout invalidateLayout];
}

- (void)viewWillLayoutSubviews {
	[self.collectionViewLayout invalidateLayout];
}

- (void)sizeDidUpdate:(NSNotification *)notification {
	_lineHeightOfQuestionFont = 0;

	self.headerView.greetingLabel.font = [self.viewModel.styleSheet fontForStyle:ApptentiveTextStyleHeaderMessage];
	self.submitButton.titleLabel.font = [self.viewModel.styleSheet fontForStyle:ApptentiveTextStyleSubmitButton];

	[self.collectionView reloadData];
	[self.collectionViewLayout invalidateLayout];
}

- (IBAction)submit:(id)sender {
	[self.view endEditing:YES];

	if ([self.viewModel validate:YES]) {
		// Consider any pending edits complete
		if (self.editingIndexPath) {
			[self.viewModel commitChangeAtIndexPath:self.editingIndexPath];
		}

		[self.viewModel submit];

		[self dismissViewControllerAnimated:YES completion:nil];

		[self.viewModel didSubmit];

		if (self.viewModel.showThankYou) {
			ApptentiveHUDViewController *HUD = [[ApptentiveHUDViewController alloc] init];
			[HUD showInAlertWindow];
			HUD.textLabel.text = self.viewModel.thankYouText;
			HUD.imageView.image = [ApptentiveBackend imageNamed:@"at_thanks"];
		}
	}
}

- (IBAction)close:(id)sender {
	[self dismissViewControllerAnimated:YES completion:nil];

	[self.viewModel didCancel];
}

- (IBAction)showAbout:(id)sender {
	[(ApptentiveNavigationController *)self.navigationController pushAboutApptentiveViewController];
}

- (void)setViewModel:(ApptentiveSurveyViewModel *)viewModel {
	_viewModel.delegate = nil;

	_viewModel = viewModel;

	viewModel.delegate = self;
}

@synthesize lineHeightOfQuestionFont = _lineHeightOfQuestionFont;

- (CGFloat)lineHeightOfQuestionFont {
	if (_lineHeightOfQuestionFont == 0) {
		UIFont *questionFont = [self.viewModel.styleSheet fontForStyle:UIFontTextStyleBody];
		_lineHeightOfQuestionFont = CGRectGetHeight(CGRectIntegral([@"A" boundingRectWithSize:CGSizeMake(MAXFLOAT, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{ NSFontAttributeName: questionFont } context:nil])) + CHOICE_VERTICAL_MARGIN;
	}

	return _lineHeightOfQuestionFont;
}

#pragma mark Collection View Data Source

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
	return [self.viewModel numberOfQuestionsInSurvey];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
	return [self.viewModel numberOfAnswersForQuestionAtIndex:section];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:
	(NSIndexPath *)indexPath {
	switch ([self.viewModel typeOfQuestionAtIndex:indexPath.section]) {
		case ATSurveyQuestionTypeMultipleLine: {
			ApptentiveSurveyMultilineCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"MultilineText" forIndexPath:indexPath];

			cell.textView.text = [self.viewModel textOfAnswerAtIndexPath:indexPath];
			cell.placeholderLabel.attributedText = [self.viewModel placeholderTextOfQuestionAtIndex:indexPath.section];
			cell.textView.delegate = self;
			cell.textView.tag = [self.viewModel textFieldTagForIndexPath:indexPath];
			cell.textView.accessibilityLabel = [self.viewModel placeholderTextOfQuestionAtIndex:indexPath.section].string;
			cell.textView.font = [self.viewModel.styleSheet fontForStyle:ApptentiveTextStyleTextInput];
			cell.textView.textColor = [self.viewModel.styleSheet colorForStyle:ApptentiveTextStyleTextInput];

			return cell;
		}
		case ATSurveyQuestionTypeSingleLine: {
			ApptentiveSurveySingleLineCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"SingleLineText" forIndexPath:indexPath];

			cell.textField.text = [self.viewModel textOfAnswerAtIndexPath:indexPath];
			cell.textField.attributedPlaceholder = [self.viewModel placeholderTextOfQuestionAtIndex:indexPath.section];
			cell.textField.delegate = self;
			cell.textField.tag = [self.viewModel textFieldTagForIndexPath:indexPath];
			cell.textField.font = [self.viewModel.styleSheet fontForStyle:ApptentiveTextStyleTextInput];
			cell.textField.textColor = [self.viewModel.styleSheet colorForStyle:ApptentiveTextStyleTextInput];

			return cell;
		}
		case ATSurveyQuestionTypeSingleSelect:
		case ATSurveyQuestionTypeMultipleSelect: {
			NSString *reuseIdentifier = [self.viewModel typeOfQuestionAtIndex:indexPath.section] == ATSurveyQuestionTypeSingleSelect ? @"Radio" : @"Checkbox";
			UIImage *buttonImage = [[ApptentiveBackend imageNamed:[self.viewModel typeOfQuestionAtIndex:indexPath.section] == ATSurveyQuestionTypeSingleSelect ? @"at_circle" : @"at_checkmark"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

			if ([self.viewModel typeOfAnswerAtIndexPath:indexPath] == ApptentiveSurveyAnswerTypeOther) {
				reuseIdentifier = [reuseIdentifier stringByAppendingString:@"Other"];
			}

			ApptentiveSurveyChoiceCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];

			cell.textLabel.text = [self.viewModel textOfChoiceAtIndexPath:indexPath];
			cell.textLabel.font = [self.viewModel.styleSheet fontForStyle:UIFontTextStyleBody];
			cell.textLabel.textColor = [self.viewModel.styleSheet colorForStyle:UIFontTextStyleBody];

			cell.button.borderColor = [self.viewModel.styleSheet colorForStyle:ApptentiveColorSeparator];
			cell.accessibilityLabel = [self.viewModel textOfChoiceAtIndexPath:indexPath];
			[cell.button setImage:buttonImage forState:UIControlStateNormal];
			cell.button.imageView.tintColor = [self.viewModel.styleSheet colorForStyle:ApptentiveColorBackground];

			cell.buttonTopConstraint.constant = (self.lineHeightOfQuestionFont - CGRectGetHeight(cell.button.bounds)) / 2.0;

			if ([self.viewModel typeOfAnswerAtIndexPath:indexPath] == ApptentiveSurveyAnswerTypeOther) {
				ApptentiveSurveyOtherCell *otherCell = (ApptentiveSurveyOtherCell *)cell;
				otherCell.textField.text = [self.viewModel textOfAnswerAtIndexPath:indexPath];
				otherCell.textField.attributedPlaceholder = [self.viewModel placeholderTextOfQuestionAtIndex:indexPath.section];
				otherCell.textField.delegate = self;
				otherCell.textField.tag = [self.viewModel textFieldTagForIndexPath:indexPath];
				otherCell.textField.font = [self.viewModel.styleSheet fontForStyle:ApptentiveTextStyleTextInput];
				otherCell.textField.textColor = [self.viewModel.styleSheet colorForStyle:ApptentiveTextStyleTextInput];
			}

			return cell;
		}
	}

	return nil;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
	if (kind == UICollectionElementKindSectionHeader) {
		ApptentiveSurveyQuestionView *view = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"Question" forIndexPath:indexPath];

		view.textLabel.text = [self.viewModel textOfQuestionAtIndex:indexPath.section];
		view.textLabel.font = [self.viewModel.styleSheet fontForStyle:UIFontTextStyleBody];
		view.textLabel.textColor = [self.viewModel.styleSheet colorForStyle:UIFontTextStyleBody];

		view.instructionsTextLabel.attributedText = [self.viewModel instructionTextOfQuestionAtIndex:indexPath.section];
		view.instructionsTextLabel.font = [self.viewModel.styleSheet fontForStyle:ApptentiveTextStyleSurveyInstructions];

		view.separatorView.backgroundColor = [self.viewModel.styleSheet colorForStyle:ApptentiveColorSeparator];

		return view;
	} else {
		return [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"Footer" forIndexPath:indexPath];
	}
}

- (BOOL)sectionAtIndexIsValid:(NSInteger)index {
	return [self.viewModel answerIsValidForQuestionAtIndex:index];
}

- (UIColor *)validColor {
	return [self.viewModel.styleSheet colorForStyle:ApptentiveColorSeparator];
}

- (UIColor *)invalidColor {
	return [self.viewModel.styleSheet colorForStyle:ApptentiveColorFailure];
}

- (UIColor *)backgroundColor {
	return [self.viewModel.styleSheet colorForStyle:ApptentiveColorBackground];
}

#pragma mark Collection View Delegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
	[self.viewModel selectAnswerAtIndexPath:indexPath];

	[self maybeAnimateOtherSizeChangeAtIndexPath:indexPath];
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
	[self.viewModel deselectAnswerAtIndexPath:indexPath];

	[self maybeAnimateOtherSizeChangeAtIndexPath:indexPath];
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
	ATSurveyQuestionType questionType = [self.viewModel typeOfQuestionAtIndex:indexPath.section];

	return (questionType == ATSurveyQuestionTypeMultipleSelect || questionType == ATSurveyQuestionTypeSingleSelect);
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
	ATSurveyQuestionType questionType = [self.viewModel typeOfQuestionAtIndex:indexPath.section];

	// Don't let them unselect the selected answer in a single select question
	if (questionType == ATSurveyQuestionTypeSingleSelect) {
		for (NSInteger answerIndex = 0; answerIndex < [self.viewModel numberOfAnswersForQuestionAtIndex:indexPath.section]; answerIndex++) {
			if ([self.viewModel answerAtIndexPathIsSelected:[NSIndexPath indexPathForItem:answerIndex inSection:indexPath.section]]) {
				return NO;
			}
		}

		return YES;
	} else if (questionType == ATSurveyQuestionTypeMultipleSelect) {
		return YES;
	} else {
		return NO;
	}
}

#pragma mark Collection View Flow Layout Delegate

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
	UIEdgeInsets sectionInset = ((UICollectionViewFlowLayout *)collectionViewLayout).sectionInset;

	CGSize itemSize = CGSizeMake(collectionView.bounds.size.width - sectionInset.left - sectionInset.right, 44.0);

	switch ([self.viewModel typeOfQuestionAtIndex:indexPath.section]) {
		case ATSurveyQuestionTypeSingleSelect:
		case ATSurveyQuestionTypeMultipleSelect: {
			CGFloat labelWidth = itemSize.width - CHOICE_HORIZONTAL_MARGIN;

			UIFont *choiceFont = [self.viewModel.styleSheet fontForStyle:UIFontTextStyleBody];
			CGSize labelSize = CGRectIntegral([[self.viewModel textOfChoiceAtIndexPath:indexPath] boundingRectWithSize:CGSizeMake(labelWidth, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{ NSFontAttributeName: choiceFont } context:nil]).size;

			itemSize.height = labelSize.height + CHOICE_VERTICAL_MARGIN;

			if ([self.viewModel typeOfAnswerAtIndexPath:indexPath] == ApptentiveSurveyAnswerTypeOther && [self.viewModel answerAtIndexPathIsSelected:indexPath]) {
				itemSize.height += 44.0;
			}

			break;
		}
		case ATSurveyQuestionTypeSingleLine:
			itemSize.height = 44.0;
			break;
		case ATSurveyQuestionTypeMultipleLine: {
			CGFloat textViewWidth = itemSize.width - MULTILINE_HORIZONTAL_MARGIN;

			NSString *text = [[self.viewModel textOfAnswerAtIndexPath:indexPath] ?: @" " stringByAppendingString:@"\n"];
			UIFont *font = [self.viewModel.styleSheet fontForStyle:ApptentiveTextStyleTextInput];
			CGSize textSize = CGRectIntegral([text boundingRectWithSize:CGSizeMake(textViewWidth, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{ NSFontAttributeName: font } context:nil]).size;

			itemSize.height = fmax(textSize.height, 17.0) + MULTILINE_VERTICAL_MARGIN + 13;
			break;
		}
	}

	return itemSize;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
	CGFloat headerWidth = CGRectGetWidth(collectionView.bounds);
	CGFloat labelWidth = headerWidth - QUESTION_HORIZONTAL_MARGIN;

	UIFont *questionFont = [self.viewModel.styleSheet fontForStyle:UIFontTextStyleBody];
	CGSize labelSize = CGRectIntegral([[self.viewModel textOfQuestionAtIndex:section] boundingRectWithSize:CGSizeMake(labelWidth, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{ NSFontAttributeName: questionFont } context:nil]).size;

	NSString *instructionsText = [[self.viewModel instructionTextOfQuestionAtIndex:section] string];
	CGSize instructionsSize = CGSizeZero;
	if (instructionsText) {
		UIFont *instructionsFont = [self.viewModel.styleSheet fontForStyle:ApptentiveTextStyleSurveyInstructions];
		instructionsSize = CGRectIntegral([instructionsText boundingRectWithSize:CGSizeMake(labelWidth, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{ NSFontAttributeName: instructionsFont } context:nil]).size;
	}

	return CGSizeMake(headerWidth, labelSize.height + QUESTION_VERTICAL_MARGIN + instructionsSize.height);
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section {
	UIEdgeInsets sectionInset = ((UICollectionViewFlowLayout *)collectionViewLayout).sectionInset;
	return CGSizeMake(collectionView.bounds.size.width - sectionInset.left - sectionInset.right, 12.0);
}

#pragma mark - Text view delegate

- (void)textViewDidBeginEditing:(UITextField *)textView {
	self.editingIndexPath = [self.viewModel indexPathForTextFieldTag:textView.tag];
	[(ApptentiveSurveyCollectionView *)self.collectionView scrollHeaderAtIndexPathToTop:self.editingIndexPath animated:YES];
}

- (BOOL)textViewShouldEndEditing:(UITextView *)textView {
	self.editingIndexPath = nil;

	return YES;
}

- (void)textViewDidChange:(UITextView *)textView {
	NSIndexPath *indexPath = [self.viewModel indexPathForTextFieldTag:textView.tag];
	ApptentiveSurveyMultilineCell *cell = (ApptentiveSurveyMultilineCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
	cell.placeholderLabel.hidden = textView.text.length > 0;

	[self.collectionView performBatchUpdates:^{
		[self.viewModel setText:textView.text forAnswerAtIndexPath:indexPath];
		CGPoint contentOffset = self.collectionView.contentOffset;
		[self.collectionViewLayout invalidateLayout];
		self.collectionView.contentOffset = contentOffset;
	} completion:nil];
}

- (void)textViewDidEndEditing:(UITextView *)textView {
	[self.viewModel commitChangeAtIndexPath:[self.viewModel indexPathForTextFieldTag:textView.tag]];
}

#pragma mark - Text field delegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
	self.editingIndexPath = [self.viewModel indexPathForTextFieldTag:textField.tag];
	[(ApptentiveSurveyCollectionView *)self.collectionView scrollHeaderAtIndexPathToTop:self.editingIndexPath animated:YES];
}

- (IBAction)textFieldChanged:(UITextField *)textField {
	NSIndexPath *indexPath = [self.viewModel indexPathForTextFieldTag:textField.tag];

	[self.viewModel setText:textField.text forAnswerAtIndexPath:indexPath];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	self.editingIndexPath = nil;

	[textField resignFirstResponder];

	return NO;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
	[self.viewModel commitChangeAtIndexPath:[self.viewModel indexPathForTextFieldTag:textField.tag]];
}

#pragma mark - View model delegate

- (void)viewModelValidationChanged:(ApptentiveSurveyViewModel *)viewModel isValid:(BOOL)valid {
	[self.collectionViewLayout invalidateLayout];

	CGFloat bottomContentOffset = self.collectionView.contentSize.height - CGRectGetHeight(self.collectionView.bounds);
	CGFloat toolbarAdjustment = (valid ? -1 : 1) * CGRectGetHeight(self.navigationController.toolbar.bounds);

	[UIView animateWithDuration:0.2 animations:^{
		if (self.collectionView.contentOffset.y >= bottomContentOffset - toolbarAdjustment) {
			self.collectionView.contentOffset = CGPointMake(0, bottomContentOffset + toolbarAdjustment);
		}
	}];

	CGPoint contentOffset = self.collectionView.contentOffset;
	[self.navigationController setToolbarHidden:valid animated:YES];
	self.collectionView.contentOffset = contentOffset;
}

- (void)viewModel:(ApptentiveSurveyViewModel *)viewModel didDeselectAnswerAtIndexPath:(NSIndexPath *)indexPath {
	[self.collectionView deselectItemAtIndexPath:indexPath animated:NO];

	[self maybeAnimateOtherSizeChangeAtIndexPath:indexPath];
}

#pragma mark - Keyboard adjustment for iOS 7 & 8

- (void)adjustForKeyboard:(NSNotification *)notification {
	CGRect keyboardRect = [self.view.window convertRect:[notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue] toView:self.collectionView.superview];

	// iOS 7 and 8 don't seem to adjust the contentInset for the keyboard
	if (![NSProcessInfo instancesRespondToSelector:@selector(isOperatingSystemAtLeastVersion:)] || ![[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){9, 0, 0}]) {
		self.collectionView.contentInset = UIEdgeInsetsMake(self.collectionView.contentInset.top, self.collectionView.contentInset.left, CGRectGetHeight(self.collectionView.bounds) - keyboardRect.origin.y, self.collectionView.contentInset.right);

		[self.collectionViewLayout invalidateLayout];
	}

	CGFloat duration = ((NSNumber *)notification.userInfo[UIKeyboardAnimationDurationUserInfoKey]).doubleValue;
	[UIView animateWithDuration:duration animations:^{
		CGPoint contentOffset = self.collectionView.contentOffset;
		[self.collectionView layoutIfNeeded];
		self.collectionView.contentOffset = contentOffset;
		if (self.editingIndexPath) {
			[(ApptentiveSurveyCollectionView *)self.collectionView scrollHeaderAtIndexPathToTop:self.editingIndexPath animated:NO];
		}
	}];
}

#pragma mark - Private 

- (void)maybeAnimateOtherSizeChangeAtIndexPath:(NSIndexPath *)indexPath {
	if ([self.viewModel typeOfAnswerAtIndexPath:indexPath] == ApptentiveSurveyAnswerTypeOther) {
		BOOL showing = [self.viewModel answerAtIndexPathIsSelected:indexPath];
		[UIView animateWithDuration:0.25 animations:^{
			[self.collectionViewLayout invalidateLayout];
		} completion:^(BOOL finished) {
			ApptentiveSurveyOtherCell *cell = (ApptentiveSurveyOtherCell *)[self.collectionView cellForItemAtIndexPath:indexPath];

			if (showing) {
				[cell.textField becomeFirstResponder];
			} else {
				[cell.textField resignFirstResponder];
			}
		}];
	}
}

@end
