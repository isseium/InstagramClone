//
//  HomeViewController.swift
//  Instagram
//
//  Created by Issei Komatsu on 2016/10/11.
//  Copyright © 2016年 Issei Komatsu. All rights reserved.
//

import UIKit
import Firebase
import FirebaseAuth
import FirebaseDatabase

class HomeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    var postArray: [PostData] = []
    
    // FIRDatabaseのobserveEventの登録状態を表す
    var observing = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        let nib = UINib(nibName: "PostTableViewCell", bundle: nil)
        tableView.registerNib(nib, forCellReuseIdentifier: "Cell")
        tableView.rowHeight = UITableViewAutomaticDimension
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if FIRAuth.auth()?.currentUser != nil {
            if observing == false {
                // 要素が追加されたらpostArrayに追加してTableViewを再表示する
                FIRDatabase.database().reference().child(CommonConst.PostPATH).observeEventType(.ChildAdded, withBlock: { snapshot in
                    
                    // PostDataクラスを生成して受け取ったデータを設定する
                    if let uid = FIRAuth.auth()?.currentUser?.uid {
                        let postData = PostData(snapshot: snapshot, myId: uid)
                        self.postArray.insert(postData, atIndex: 0)
                        
                        // TableViewを再表示する
                        self.tableView.reloadData()
                    }
                })
                
                // 要素が変更されたら該当のデータをpostArrayから一度削除した後に新しいデータを追加してTableViewを再表示する
                FIRDatabase.database().reference().child(CommonConst.PostPATH).observeEventType(.ChildChanged, withBlock: { snapshot in
                    if let uid = FIRAuth.auth()?.currentUser?.uid {
                        // PostDataクラスを生成して受け取ったデータを設定する
                        let postData = PostData(snapshot: snapshot, myId: uid)
                        
                        // 保持している配列からidが同じものを探す
                        var index: Int = 0
                        for post in self.postArray {
                            if post.id == postData.id {
                                index = self.postArray.indexOf(post)!
                                break
                            }
                        }
                        
                        // 差し替えるため一度削除する
                        self.postArray.removeAtIndex(index)
                        
                        // 削除したところに更新済みのでデータを追加する
                        self.postArray.insert(postData, atIndex: index)
                        
                        // TableViewの現在表示されているセルを更新する
                        self.tableView.reloadData()
                    }
                })
                
                // FIRDatabaseのobserveEventが上記コードにより登録されたため
                // trueとする
                observing = true
            }
        } else {
            if observing == true {
                // ログアウトを検出したら、一旦テーブルをクリアしてオブザーバーを削除する。
                // テーブルをクリアする
                postArray = []
                tableView.reloadData()
                // オブザーバーを削除する
                FIRDatabase.database().reference().removeAllObservers()
                
                // FIRDatabaseのobserveEventが上記コードにより解除されたため
                // falseとする
                observing = false
            }
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return postArray.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        // セルを取得してデータを設定する
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as! PostTableViewCell
        cell.setPostData(postArray[indexPath.row])
        
        // セル内のボタンのアクションをソースコードで設定する
        cell.likeButton.addTarget(self, action:#selector(handleButton(_:event:)), forControlEvents:  UIControlEvents.TouchUpInside)

        cell.commentButton.addTarget(self, action:#selector(handleComment(_:event:)), forControlEvents:  UIControlEvents.TouchUpInside)
        
        return cell
    }
    
    func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        // Auto Layoutを使ってセルの高さを動的に変更する
        return UITableViewAutomaticDimension
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        // セルをタップされたら何もせずに選択状態を解除する
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    // セル内のボタンがタップされた時に呼ばれるメソッド
    func handleButton(sender: UIButton, event:UIEvent) {
        
        // タップされたセルのインデックスを求める
        let touch = event.allTouches()?.first
        let point = touch!.locationInView(self.tableView)
        let indexPath = tableView.indexPathForRowAtPoint(point)
        
        // 配列からタップされたインデックスのデータを取り出す
        let postData = postArray[indexPath!.row]
        
        // Firebaseに保存するデータの準備
        if let uid = FIRAuth.auth()?.currentUser?.uid {
            if postData.isLiked {
                // すでにいいねをしていた場合はいいねを解除するためIDを取り除く
                var index = -1
                for likeId in postData.likes {
                    if likeId == uid {
                        // 削除するためにインデックスを保持しておく
                        index = postData.likes.indexOf(likeId)!
                        break
                    }
                }
                postData.likes.removeAtIndex(index)
            } else {
                postData.likes.append(uid)
            }
            
            let imageString = postData.imageString
            let name = postData.name
            let caption = postData.caption
            let time = (postData.date?.timeIntervalSinceReferenceDate)! as NSTimeInterval
            let likes = postData.likes
            let comments = postData.comments
            
            // 辞書を作成してFirebaseに保存する
            let post = ["caption": caption!, "image": imageString!, "name": name!, "time": time, "likes": likes, "comments": comments]
            let postRef = FIRDatabase.database().reference().child(CommonConst.PostPATH)
            postRef.child(postData.id!).setValue(post)
        }
    }
    
    func handleComment(sender: UIButton, event:UIEvent) {
        let alert:UIAlertController = UIAlertController(title:"コメント",
                                                        message: "コメントを入力してください",
                                                        preferredStyle: UIAlertControllerStyle.Alert)
        
        let cancelAction:UIAlertAction = UIAlertAction(title: "Cancel",
                                                       style: UIAlertActionStyle.Cancel,
                                                       handler:{
                                                        (action:UIAlertAction!) -> Void in
                                                        print("Cancel")
        })
        let defaultAction:UIAlertAction = UIAlertAction(title: "OK",
                                                        style: UIAlertActionStyle.Default,
                                                        handler:{
                                                            (action:UIAlertAction!) -> Void in
                                                            
                                                            var text = ""
                                                            let textFields:Array<UITextField>? =  alert.textFields as Array<UITextField>?
                                                            if textFields != nil {
                                                                for textField:UITextField in textFields! {
                                                                    //各textにアクセス
                                                                    text = text + textField.text!
                                                                }
                                                            }
                                                            
                                                            let touch = event.allTouches()?.first
                                                            let point = touch!.locationInView(self.tableView)
                                                            let indexPath = self.tableView.indexPathForRowAtPoint(point)

                                                            
                                                            // 配列からタップされたインデックスのデータを取り出す
                                                            let postData = self.postArray[indexPath!.row]
                                                            
                                                            // Firebaseに保存するデータの準備
                                                            if let uid = FIRAuth.auth()?.currentUser?.uid {
                                                                let postname = FIRAuth.auth()!.currentUser!.displayName!
                                                                let comment = [
                                                                    "uid": uid,
                                                                    "name": postname,
                                                                    "text": text
                                                                ]
                                                                
                                                                postData.comments.append(comment)
                                                                
                                                                let imageString = postData.imageString
                                                                let name = postData.name
                                                                let caption = postData.caption
                                                                let time = (postData.date?.timeIntervalSinceReferenceDate)! as NSTimeInterval
                                                                let likes = postData.likes
                                                                let comments = postData.comments
                                                                
                                                                // 辞書を作成してFirebaseに保存する
                                                                let post = ["caption": caption!, "image": imageString!, "name": name!, "time": time, "likes": likes, "comments": comments]
                                                                let postRef = FIRDatabase.database().reference().child(CommonConst.PostPATH)
                                                                postRef.child(postData.id!).setValue(post)
                                                            }
                                                            
        })
        alert.addAction(cancelAction)
        alert.addAction(defaultAction)
        
        //textfiledの追加
        alert.addTextFieldWithConfigurationHandler({(text:UITextField!) -> Void in
        })
        presentViewController(alert, animated: true, completion: nil)
    }
}
