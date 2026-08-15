class ContinueStatement {
    constructor({
        keyword,
        semicolon
    }, loc) {
        this.keyword = keyword;
        this.semicolon = semicolon;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.keyword.visit(cb, parents);
        this.semicolon.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.ContinueStatement = ContinueStatement;
