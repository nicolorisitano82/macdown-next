//
//  MDDiagramRenderer.h
//  MacDownQuickLook
//
//  Drawing the diagrams and the formulas before the page is handed over.
//
//  The preview page has no scripts in it, on purpose: `default-src 'none'`
//  and nothing to run. So a diagram cannot draw itself there and a formula
//  cannot typeset itself — they are drawn here, in a web view of the
//  extension's own, and what reaches the page is finished SVG.
//

#import <Foundation/Foundation.h>


/// What has to be drawn, and therefore which library draws it.
typedef NS_ENUM(NSUInteger, MDDrawingKind) {
    /// A ```mermaid fence: flowcharts, sequences, gantts, and the rest.
    MDDrawingMermaid,
    /// A fence named after one of Graphviz's layout engines.
    MDDrawingGraphviz,
    /// `\[…\]` — a formula on a line of its own.
    MDDrawingMathDisplay,
    /// `\(…\)` — a formula inside a line.
    MDDrawingMathInline,
};


/// One thing to draw, and where it sits in the page.
@interface MDDrawingJob : NSObject
/// The diagram or the TeX as written, with the HTML escaping undone.
@property (readonly, copy, nonatomic) NSString *source;
/// The whole fence, or the whole formula with its delimiters.
@property (readonly, nonatomic) NSRange range;
@property (readonly, nonatomic) MDDrawingKind kind;
/// Which Graphviz engine to lay it out with; nil for anything else.
@property (readonly, copy, nonatomic) NSString *engine;
@end


/// Everything in that HTML that wants drawing, in document order.
///
/// Fences are recognized in both shapes hoedown emits — the bare
/// `<pre><code>` and the `<div>` the patched renderer wraps around it — and
/// formulas by the delimiters hoedown leaves behind, which are the ones
/// MathJax looks for. Nothing inside a code block counts: a fence that
/// *talks* about `\[x\]` is not a formula.
extern NSArray<MDDrawingJob *> *MDDrawingJobsInHTML(NSString *html);

/// The HTML with each job replaced by its drawing.
///
/// `drawings` runs parallel to `jobs`; a drawing that is missing, empty or
/// `NSNull` leaves its source as it stands. The source of a diagram nobody
/// could draw is the honest thing to show — it is what the preview showed
/// before it could draw any.
extern NSString *MDHTMLByDrawingJobs(NSString *html,
                                     NSArray<MDDrawingJob *> *jobs,
                                     NSArray *drawings);

/// That SVG with anything that could run taken out of it.
///
/// The libraries put no scripts in what they draw, but what they drew came
/// from a document that arrived from anywhere, and the page it lands in is
/// the one place in this extension where markup is not escaped.
extern NSString *MDSVGWithoutScripts(NSString *svg);


/// Where the libraries are, by the name this renderer asks for them.
extern NSString * const MDMermaidResource;   ///< mermaid.min.js
extern NSString * const MDGraphvizResource;  ///< viz.js
extern NSString * const MDMathResource;      ///< tex-svg.js


@interface MDDiagramRenderer : NSObject

/// Draws each job and answers on the main queue.
///
/// One drawing per job, in the same order, with `NSNull` where the library
/// refused — a diagram with a mistake in it must not cost the page its
/// other diagrams. Only the libraries the jobs actually need are loaded:
/// a document with one flowchart in it does not pay for Graphviz or for
/// MathJax.
///
/// The whole batch has `budget` seconds: what is drawn by then is what the
/// page gets, because a preview that arrives late has not arrived.
///
/// `styleSheet` is what the drawings need in order to sit correctly in the
/// page — MathJax's own rules, when there were formulas — or nil.
+ (void)drawJobs:(NSArray<MDDrawingJob *> *)jobs
       resources:(NSDictionary<NSString *, NSURL *> *)resources
          within:(NSTimeInterval)budget
      completion:(void (^)(NSArray *drawings, NSString *styleSheet))completion;

@end
