import UIKit

final class SeriesCellAdapter: BaseCellAdapter<Series> {
    private var selectAction: ((Series) -> Void)?

    init(viewModel: Series, select: ((Series) -> Void)?) {
        self.selectAction = select
        super.init(viewModel: viewModel)
    }

    override func cellForItem(at index: IndexPath, context: CollectionContext) -> UICollectionViewCell? {
        let cell = context.dequeueReusableNibCell(type: SeriesCell.self, for: index)
        cell.configure(viewModel)
        return cell
    }

    override func didSelect(at index: IndexPath) {
        self.selectAction?(viewModel)
    }
}
