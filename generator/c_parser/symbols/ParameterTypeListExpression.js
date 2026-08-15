class ParameterTypeListExpression {
    constructor({
        open,
        params,
        close
    }, loc) {
        this.open = open;
        this.params = params;
        this.close = close;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.open.visit(cb, parents);

        for (const param of this.params) {
            param.visit(cb, parents);
        }

        this.close.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.ParameterTypeListExpression = ParameterTypeListExpression;
