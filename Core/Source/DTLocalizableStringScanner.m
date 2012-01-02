//
//  DTLocalizableStringScanner.m
//  genstrings2
//
//  Created by Oliver Drobnik on 29.12.11.
//  Copyright (c) 2011 Drobnik KG. All rights reserved.
//

#import "DTLocalizableStringScanner.h"
#import "NSScanner+DTLocalizableStringScanner.h"
#import "NSString+DTLocalizableStringScanner.h"

@interface DTLocalizableStringScanner ()

@property (nonatomic, retain) NSMutableDictionary *validMacros;

@end

@implementation DTLocalizableStringScanner
{
    NSString *_string;
    NSURL *_url;
    NSMutableDictionary *_validMacros;
    
    // lookup bitmask what delegate methods are implemented
	struct 
	{
		unsigned int delegateSupportsStart:1;
		unsigned int delegateSupportsEnd:1;
        unsigned int delegateSupportsDidFindToken:1;
	} _delegateFlags;
    
    __weak id <DTLocalizableStringScannerDelegate> _delegate;
}

- (id)initWithContentsOfURL:(NSURL *)url
{
    self = [super init];
    
    if (self)
    {
        _string = [[NSString alloc] initWithContentsOfURL:url usedEncoding:NULL error:NULL];
        
        if (!_string)
        {
            return nil;
        }
        
        _url = [url copy]; // to have a reference later
    }
    
    return self;
}

- (BOOL)scanFile
{
    if (_delegateFlags.delegateSupportsStart)
    {
        [_delegate localizableStringScannerDidStartDocument:self];
    }
    
    NSScanner *scanner = [NSScanner scannerWithString:_string];
    
    NSDictionary *validMacros = self.validMacros;
    
    NSCharacterSet *validMacroCharacters = [NSCharacterSet alphanumericCharacterSet];
    
    while (![scanner isAtEnd]) 
    {
        NSString *macro = nil;
        NSArray *parameters = nil;
        
        // skip to next word
        [scanner scanUpToCharactersFromSet:validMacroCharacters intoString:NULL];
        
        if ([scanner scanMacro:&macro andParameters:&parameters parametersAreBare:NO])
        {
            NSArray *paramNames = [validMacros objectForKey:macro];
            
            if (paramNames)
            {
                // ignore macros that are not registered
                
                if ([paramNames count] == [parameters count])
                {
                    // scanned parameters must match up with registered names
                    
                    NSMutableDictionary *tmpDict = [NSMutableDictionary dictionary];
                    
                    for (NSUInteger i=0; i<[paramNames count]; i++)
                    {
                        NSString *paramName = [paramNames objectAtIndex:i];
                        NSString *paramValue = [parameters objectAtIndex:i];
                        
                        // number the parameters if necessary
                        paramValue = [paramValue stringByNumberingFormatPlaceholders];
                        
                        [tmpDict setObject:paramValue forKey:paramName];
                    }
                    
                    if (_delegateFlags.delegateSupportsDidFindToken)
                    {
                        [_delegate localizableStringScanner:self
                                               didFindToken:tmpDict];
                    }
                }
                else
                {
                    // macro parameter count is different scanned versus registered, ignoring it
                }
            }
        }
        else
        {
            // is a word, but not a valid macro
            [scanner scanCharactersFromSet:validMacroCharacters intoString:NULL];
        }
    }
    
    if (_delegateFlags.delegateSupportsEnd)
    {
        [_delegate localizableStringScannerDidEndDocument:self];
    }
    
    return YES;
}

- (void)registerMacroWithPrototypeString:(NSString *)prototypeString
{
    NSString *macroName = nil;
    NSArray *parameters = nil;
    
    NSScanner *scanner = [NSScanner scannerWithString:prototypeString];
    
    if ([scanner scanMacro:&macroName andParameters:&parameters parametersAreBare:YES])
    {
        if (macroName && parameters)
        {
            [self.validMacros setObject:parameters forKey:macroName];
        }
    }
    else
    {
        NSLog(@"Invalid Macro: %@", prototypeString);
    }
}

#pragma mark Properties

- (NSMutableDictionary *)validMacros
{
    if (!_validMacros)
    {
        _validMacros = [[NSMutableDictionary alloc] init];
        
        // register the standard macros
        [self registerMacroWithPrototypeString:@"NSLocalizedString(key, comment)"];
        [self registerMacroWithPrototypeString:@"NSLocalizedStringFromTable(key, tbl, comment)"];
        [self registerMacroWithPrototypeString:@"NSLocalizedStringFromTableInBundle(key, tbl, bundle, comment)"];
        [self registerMacroWithPrototypeString:@"NSLocalizedStringWithDefaultValue(key, tbl, bundle, val, comment)"];
        
        /* fehlen noch: statt @"bla" wird CFSTR("bla") verwendet
         #define CFCopyLocalizedString(key, comment) \
         #define CFCopyLocalizedStringFromTable(key, tbl, comment) \
         #define CFCopyLocalizedStringFromTableInBundle(key, tbl, bundle, comment) \
         #define CFCopyLocalizedStringWithDefaultValue(key, tbl, bundle, value, comment) \
         */
    }
    
    return _validMacros;
}

- (void)setDelegate:(id<DTLocalizableStringScannerDelegate>)delegate
{
    if (_delegate != delegate)
    {
        _delegateFlags.delegateSupportsStart = [delegate respondsToSelector:@selector(localizableStringScannerDidStartDocument:)];
        _delegateFlags.delegateSupportsEnd = [delegate respondsToSelector:@selector(localizableStringScannerDidEndDocument:)];   
        _delegateFlags.delegateSupportsDidFindToken = [delegate respondsToSelector:@selector(localizableStringScanner:didFindToken:)];
        
        _delegate = delegate;
    }
}

@synthesize validMacros = _validMacros;
@synthesize delegate = _delegate;

@end
