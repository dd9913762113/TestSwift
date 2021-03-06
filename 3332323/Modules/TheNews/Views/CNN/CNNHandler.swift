//
//  Created by Daniel on 12/12/20.
//

import UIKit

class CNNHandler: NewsTableHandler {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return articles.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: CNNCell.identifier) as! CNNCell
        
        let article = articles[indexPath.row]
        cell.load(article: article, downloader: TheNewsImageDownloader.shared)

        return cell
    }

}


/**
 
 
 
 
 */
