/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import ARKit
import SceneKit
import UIKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    /// The view controller that displays the status and "restart experience" UI.
    lazy var statusViewController: StatusViewController = {
        return childViewControllers.lazy.compactMap({ $0 as? StatusViewController }).first!
    }()
    
    /// A serial queue for thread safety when modifying the SceneKit node graph.
    let updateQueue = DispatchQueue(label: Bundle.main.bundleIdentifier! +
        ".serialSceneKitQueue")
    
    /// Convenience accessor for the session owned by ARSCNView.
    var session: ARSession {
        return sceneView.session
    }
    
    // MARK: - View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true

        // Hook up status view controller callback(s).
        statusViewController.restartExperienceHandler = { [unowned self] in
            self.restartExperience()
        }
    }

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		// Prevent the screen from being dimmed to avoid interuppting the AR experience.
		UIApplication.shared.isIdleTimerDisabled = true

        // Start the AR experience
        resetTracking()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

        session.pause()
	}

    // MARK: - Session management (Image detection setup)
    
    /// Prevents restarting the session while a restart is in progress.
    var isRestartAvailable = true

    /// Creates a new AR configuration to run on the `session`.
    /// - Tag: ARReferenceImage-Loading
	func resetTracking() {
        
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.detectionImages = referenceImages
        configuration.maximumNumberOfTrackedImages = 1
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        statusViewController.scheduleMessage("Look around to detect images", inSeconds: 7.5, messageType: .contentPlacement)
	}

    // MARK: - ARSCNViewDelegate (Image detection results)
    /// - Tag: ARImageAnchor-Visualizing
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        let referenceImage = imageAnchor.referenceImage
        updateQueue.async {
            let physicalWidth = imageAnchor.referenceImage.physicalSize.width
            let physicalHeight = imageAnchor.referenceImage.physicalSize.height
            
            // Create a plane to visualize the initial position of the detected image.
            let plane = SCNPlane(width: physicalWidth,
                                 height: physicalHeight)
            // This bit is important. It helps us create occlusion so virtual things stay hidden behind the detected image
            plane.firstMaterial?.colorBufferWriteMask = .alpha
            
            let planeNode = SCNNode(geometry: plane)
            planeNode.opacity = 0.25
            
            /*
             `SCNPlane` is vertically oriented in its local coordinate space, but
             `ARImageAnchor` assumes the image is horizontal in its local space, so
             rotate the plane to match.
             */
            planeNode.eulerAngles.x = -.pi / 2
            planeNode.renderingOrder = -1
            planeNode.opacity = 1
            /*
             Image anchors are not tracked after initial detection, so create an
             animation that limits the duration for which the plane visualization appears.
             */
//            self.imageHighlightAction(on: planeNode, completionHandler: {
            if referenceImage.name == "birthday"{
                self.displayTextView(on: planeNode, xOffset: physicalWidth)
                   self.displayWebView(on: planeNode, xOffset: physicalWidth, urlt: "https://www.youtube.com/watch?v=pECxr5COWKI")
            }
            if referenceImage.name == "giftcard" {
                self.displayWebView(on: planeNode, xOffset: physicalWidth, urlt: "https://item.mercari.com/jp/m25816679903")
            }
        
            
//                self.displayDetailView(on: planeNode, xOffset: physicalWidth)
                // Animate the WebView to the right
//                self.displayWebView(on: planeNode, xOffset: physicalWidth)
//            })
    
            // Add the plane visualization to the scene.
            node.addChildNode(planeNode)
        }

        DispatchQueue.main.async {
            let imageName = referenceImage.name ?? ""
            self.statusViewController.cancelAllScheduledMessages()
            self.statusViewController.showMessage("Detected image “\(imageName)”")
        }
    }

    var imageHighlightAction: SCNAction {
        return .sequence([
            .wait(duration: 0.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOpacity(to: 0.15, duration: 0.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOut(duration: 0.5),
            .removeFromParentNode()
        ])
    }
    
    
    func displayTextView(on rootNode: SCNNode, xOffset: CGFloat) {
        let text = SCNText(string: "Happy Birthday Rohit!!", extrusionDepth: 0.1)
        text.font = UIFont.italicSystemFont(ofSize: 1.0)
        text.flatness = 0.02
        text.isWrapped = true
//        text.containerFrame = CGRect(x: 0, y: 0, width: xOffset, height: xOffset * 1.4)
        text.firstMaterial?.diffuse.contents = UIColor.yellow
        
        let textNode = SCNNode(geometry: text)
        
        let fontSize = Float(0.10)
        textNode.scale = SCNVector3(fontSize, fontSize, fontSize)
//        textNode.position = SCNVector3Zero
        textNode.position.z += 0.5
        rootNode.addChildNode(textNode)
        textNode.runAction(.sequence([
            .wait(duration: 1.0),
            .fadeOpacity(to: 1.0, duration: 1.5),
            .moveBy(x: xOffset * -1.1, y: 0, z: -0.05, duration: 1.5),
            .moveBy(x: 0, y: 0, z: -0.05, duration: 0.2)
            ])
        )
    }
    
    func displayDetailView(on rootNode: SCNNode, xOffset: CGFloat) {
        let detailPlane = SCNPlane(width: xOffset*2, height: xOffset * 2.4)
        detailPlane.cornerRadius = 0.25
        
        let detailNode = SCNNode(geometry: detailPlane)
        detailNode.geometry?.firstMaterial?.diffuse.contents = SKScene(fileNamed: "DetailScene.scn")
        
        // Due to the origin of the iOS coordinate system, SCNMaterial's content appears upside down, so flip the y-axis.
        detailNode.geometry?.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)
        detailNode.position.z += 0.5
        detailNode.opacity = 0
        
        rootNode.addChildNode(detailNode)
        detailNode.runAction(.sequence([
            .wait(duration: 1.0),
            .fadeOpacity(to: 1.0, duration: 1.5),
            .moveBy(x: xOffset * -1.1, y: 0, z: -0.05, duration: 1.5),
            .moveBy(x: 0, y: 0, z: -0.05, duration: 0.2)
            ])
        )
    }
    
    func displayVideoView(on rootNode: SCNNode, xOffset: CGFloat) {
        let videoNode = SKVideoNode(fileNamed: "hbd.mp4")
        videoNode.play()
        // set the size (just a rough one will do)
        let videoScene = SKScene(size: CGSize(width: xOffset, height: xOffset * 1.4))
        // center our video to the size of our video scene
        videoNode.position = CGPoint(x: videoScene.size.width / 2, y: videoScene.size.height / 2)
        // invert our video so it does not look upside down
        videoNode.yScale = -1.0
        // add the video to our scene
        videoScene.addChild(videoNode)
        // create a plan that has the same real world height and width as our detected image
        let vplane = SCNPlane(width: xOffset, height: xOffset * 1.4)
        // set the first materials content to be our video scene
        vplane.firstMaterial?.diffuse.contents = videoScene
        // create a node out of the plane
        let vplaneNode = SCNNode(geometry: vplane)
        // since the created node will be vertical, rotate it along the x axis to have it be horizontal or parallel to our detected image
//        vplaneNode.eulerAngles.x = -Float.pi / 2
        vplaneNode.position.z += 0.1
        vplaneNode.opacity = 0
        // finally add the plane node (which contains the video node) to the added node
        rootNode.addChildNode(vplaneNode)

        vplaneNode.runAction(.sequence([
            .wait(duration: 1.0),
            .fadeOpacity(to: 1.0, duration: 1.5),
            .moveBy(x: xOffset * 1.1, y: 0, z: -0.05, duration: 1.5),
            .moveBy(x: 0, y: 0, z: -0.05, duration: 0.2)
            ])
        )
    }
    
    func displayWebView(on rootNode: SCNNode, xOffset: CGFloat, urlt: String) {
        // Xcode yells at us about the deprecation of UIWebView in iOS 12.0, but there is currently
        // a bug that does now allow us to use a WKWebView as a texture for our webViewNode
        // Note that UIWebViews should only be instantiated on the main thread!
        DispatchQueue.main.async {
            let request = URLRequest(url: URL(string: urlt)!)
            let webView = UIWebView(frame: CGRect(x: 0, y: 0, width: 400, height: 672))
            webView.loadRequest(request)
            
            let webViewPlane = SCNPlane(width: xOffset, height: xOffset * 2.4)
            webViewPlane.cornerRadius = 0.25
            
            let webViewNode = SCNNode(geometry: webViewPlane)
            
            // Set the web view as webViewPlane's primary texture
            webViewNode.geometry?.firstMaterial?.diffuse.contents = webView
            webViewNode.position.z += 0.1
            webViewNode.opacity = 0
            
            rootNode.addChildNode(webViewNode)
            webViewNode.runAction(.sequence([
                .wait(duration: 1.0),
                .fadeOpacity(to: 1.0, duration: 1.5),
                .moveBy(x: xOffset * 1.1, y: 0, z: -0.05, duration: 1.5),
                .moveBy(x: 0, y: 0, z: -0.05, duration: 0.2)
                ])
            )
        }
    }
}
