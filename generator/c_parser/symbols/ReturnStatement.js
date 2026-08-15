class ReturnStatement {
    constructor({
        keyword,
        expression,
        semicolon
    }, loc) {
        this.keyword = keyword;
        this.expression = expression;
        this.semicolon = semicolon;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.keyword.visit(cb, parents);
        if (this.expression) {
            this.expression.visit(cb, parents);
        }
        this.semicolon.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.ReturnStatement = ReturnStatement;
