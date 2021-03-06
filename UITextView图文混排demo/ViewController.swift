//
//  ViewController.swift
//  UITextView图文混排demo
//
//  Created by 罗威 on 2021/3/6.
//

import UIKit
import JXPhotoBrowser

class ViewController: UIViewController {
    @IBOutlet weak var textView: UITextView!
    var images = [UIImage]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //添加点击手势
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapOnImage(_:)))
        textView.addGestureRecognizer(tap)
        
        //从用户目录读取之前保存的rtfd(带有附件的富文本文件)
        loadAttributedText()
        
    }
    
    @IBAction func insertImage(){
        importPicture()
    }
    
    @IBAction func loadAttributedText(){
        if let aString = loadAttributedString(id_string: "1"){
            textView.attributedText = prepareTextImages(aString: aString)
        }
    }
    
    @IBAction func saveAttributedText(){
        saveAttributedString(id_string: "1", aString: textView.attributedText)
    }
    
    @IBAction func clearTextView(){
        textView.attributedText = nil
    }
}

extension ViewController:UIImagePickerControllerDelegate,UINavigationControllerDelegate{
    func importPicture() {
        let picker = UIImagePickerController()
        picker.delegate = self
        present(picker, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.originalImage] as? UIImage else { return }
        insertPictureToTextView(image: image)
        dismiss(animated: true)
    }
    
    func insertPictureToTextView(image:UIImage){
        //创建附件
        let attachment = NSTextAttachment()
        //设置附件的大小
        let imageAspectRatio = image.size.height / image.size.width
        let peddingX:CGFloat =  0
        let imageWidth = textView.frame.width - 2 * peddingX
        let imageHeight = imageWidth * imageAspectRatio
        attachment.image = UIImage(data: image.jpegData(compressionQuality: 0.5)!)
        attachment.bounds = CGRect(x: 0, y: 0,
                                   width: imageWidth,
                                   height: imageHeight)
        //将附件转成NSAttributedString类型的属性化文本
        let attImage = NSAttributedString(attachment: attachment)
        //获取textView的所有文本，转成可变的文本
        let mutableStr = NSMutableAttributedString(attributedString: textView.attributedText)
        //获得目前光标的位置
        let selectedRange = textView.selectedRange
        //插入附件
        mutableStr.insert(attImage, at: selectedRange.location)
        mutableStr.insert(NSAttributedString(string: "\n"), at: selectedRange.location+1)//插入图片后另起一行
//        //格式化mutableStr
//        mutableStr.addAttribute(NSAttributedString.Key.font, value: UIFont(name: "Noto Sans S Chinese", size: 20)!, range: NSMakeRange(0,mutableStr.length))
        textView.attributedText = mutableStr
    }
    
    
}

extension ViewController{
    @objc func tapOnImage(_ sender: UITapGestureRecognizer){
        guard let textView = sender.view as? UITextView else{
            return
        }
        let layoutManager = textView.layoutManager
        var location = sender.location(in: textView)
        location.x -= textView.textContainerInset.left
        location.y -= textView.textContainerInset.top
        
        //推算触摸点处的字符下标
        let characterIndex = layoutManager.characterIndex(
            for: location,
            in: textView.textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil)
        
        if characterIndex < textView.textStorage.length{
            //识别字符下标characterIndex处的富文本信息
            let attachment = textView.attributedText.attribute(NSAttributedString.Key.attachment,
                                                               at: characterIndex,
                                                               effectiveRange: nil) as? NSTextAttachment
            //1.字符下标characterIndex处为图片附件，则展示它
            if let attachment = attachment{
                textView.resignFirstResponder()
                //获取image
                guard let attachImage = attachment.image(forBounds: textView.bounds, textContainer: textView.textContainer, characterIndex: characterIndex)else{
                    print("无法获取image")
                    return
                }
                //展示image
                let browser = JXPhotoBrowser()
                browser.numberOfItems = { 1 }
                browser.reloadCellAtIndex = { context in
                    let browserCell = context.cell as? JXPhotoBrowserImageCell
                    browserCell?.imageView.image = attachImage
                }
                browser.show()
            //2.字符下标characterIndex处为字符，则将光标移到触摸的字符下标
            }else{
                textView.becomeFirstResponder()
                textView.selectedRange = NSMakeRange(characterIndex+1, 0)
            }
        }
    }
}

extension ViewController{
    //MARK:-存储富文本到用户目录
    func saveAttributedString(id_string:String,aString:NSAttributedString?) {
        do {
            let file = try aString?.fileWrapper (
                from: NSMakeRange(0, aString!.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
            
            if let dir = FileManager.default.urls (for: .documentDirectory, in: .userDomainMask) .first {
                let path_file_name = dir.appendingPathComponent (id_string)
                do {
                    try file!.write (to: path_file_name, options: .atomic, originalContentsURL: nil)
                } catch {
                    // Error handling
                }
            }
        } catch {
            //Error handling
        }
        
    }
    //MARK:-从用户目录读取富文本
    func loadAttributedString(id_string:String) -> NSAttributedString?{
        if let dir = FileManager.default.urls (for: .documentDirectory, in: .userDomainMask) .first {
            let path_file_name = dir.appendingPathComponent (id_string)
            do{
                let aString = try NSAttributedString(
                    url: path_file_name,
                    options: [.documentType:NSAttributedString.DocumentType.rtfd],
                    documentAttributes: nil)
    //            print("load \(date_string) attributedString")
                return aString
            }catch{
                //
            }
        }
        return nil
    }
    
    //MARK:-让富文本图片正常地显示
    private func prepareTextImages(aString:NSAttributedString) -> NSMutableAttributedString {
        let mutableText = NSMutableAttributedString(attributedString: aString)
        let width  = self.textView.frame.width
        mutableText.enumerateAttribute(NSAttributedString.Key.attachment, in: NSRange(location: 0, length: mutableText.length), options: [], using: { [width] (object, range, pointer) in
            let textViewAsAny: Any = self.textView!
            if let attachment = object as? NSTextAttachment, let img = attachment.image(forBounds: self.textView.bounds, textContainer: textViewAsAny as? NSTextContainer, characterIndex: range.location){
                let aspect = img.size.width / img.size.height
                if img.size.width <= width {
                    attachment.bounds = CGRect(x: 0, y: 0, width: img.size.width, height: img.size.height)
                    return
                }
                let height = width / aspect
                attachment.bounds = CGRect(x: 0, y: 0, width: width, height: height)
            }
            })
        return mutableText
    }
}
