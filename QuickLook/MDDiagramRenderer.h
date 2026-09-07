//
//  MDDiagramRenderer.h
//  MacDownQuickLook
//
//  Drawing the mermaid fences before the page is handed over.
//
//  The preview page has no scripts in it, on purpose: `default-src 'none'`
//  and nothing to run. So the diagrams cannot draw themselves there — they
//  are drawn here, in a web view of the extension's own, and what reaches
//  the page is finished SVG.
//

#import <Foundation/Foundation.h>


/// One fenced diagram in the page, and where it sits.
@interface MDDiagramFence : NSObject
/// The diagram as written, with the HTML escaping undone.
@property (readonly, copy, nonatomic) NSString *source;
/// The whole fence in the HTML, so it can be replaced by its drawing.
@property (readonly, nonatomic) NSRange range;
@end


/// The mermaid fences in that HTML, in document order.
///
/// Both shapes hoedown emits are recognized: the bare `<pre><code>` and the
/// `<div>` the patched renderer wraps around it when it has a source
/// position to report.
extern NSArray<MDDiagramFence *> *MDDiagramFencesInHTML(NSString *html);

/// The HTML with each fence replaced by its drawing.
///
/// `drawings` runs parallel to `fences`; a drawing that is missing, empty or
/// `NSNull` leaves its fence as it stands. The source of a diagram nobody
/// could draw is the honest thing to show — it is what the preview showed
/// before it could draw any.
extern NSString *MDHTMLByDrawingFences(NSString *html,
                                       NSArray<MDDiagramFence *> *fences,
                                       NSArray *drawings);

/// That SVG with anything that could run taken out of it.
///
/// mermaid puts no scripts in what it draws, but the diagram comes from a
/// document that arrived from anywhere, and the page it lands in is the one
/// place in this extension where markup is not escaped. Belt and braces.
extern NSString *MDSVGWithoutScripts(NSString *svg);


@interface MDDiagramRenderer : NSObject

/// Draws each source with mermaid and answers on the main queue.
///
/// One drawing per source, in the same order, with `NSNull` where mermaid
/// refused — a diagram with a syntax error must not cost the page its other
/// diagrams. The whole batch has `budget` seconds: what is drawn by then is
/// what the page gets, because a preview that arrives late has not arrived.
///
/// `script` is mermaid itself, read and put in the page rather than linked:
/// a web view loading an HTML string will not fetch a file beside it.
+ (void)drawSources:(NSArray<NSString *> *)sources
      mermaidScript:(NSURL *)script
             within:(NSTimeInterval)budget
         completion:(void (^)(NSArray *drawings))completion;

@end
